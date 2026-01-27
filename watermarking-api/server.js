// server.js
// Watermarking REST API with SSE progress streaming

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const { v4: uuidv4 } = require('uuid');
const { spawn } = require('child_process');
const fs = require('fs');
const crypto = require('crypto');

const app = express();

// Configuration
const PORT = process.env.PORT || 8080;
const API_KEY = process.env.API_KEY;
const DEFAULT_STRENGTH = parseInt(process.env.DEFAULT_STRENGTH, 10) || 10;
const JOB_TTL_MS = 5 * 60 * 1000; // 5 minutes

// Validate API_KEY is set
if (!API_KEY) {
  console.error('ERROR: API_KEY environment variable is required');
  process.exit(1);
}

// CORS configuration
const corsOptions = {
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'X-API-Key'],
  exposedHeaders: ['Content-Disposition'],
};
app.use(cors(corsOptions));

// In-memory job storage
const jobs = new Map();

// Cleanup expired jobs periodically
setInterval(() => {
  const now = Date.now();
  for (const [jobId, job] of jobs.entries()) {
    if (now - job.createdAt > JOB_TTL_MS) {
      // Clean up the file
      if (job.markedImagePath && fs.existsSync(job.markedImagePath)) {
        try {
          fs.unlinkSync(job.markedImagePath);
          console.log(`Cleaned up expired job file: ${job.markedImagePath}`);
        } catch (err) {
          console.error(`Error cleaning up file ${job.markedImagePath}:`, err);
        }
      }
      jobs.delete(jobId);
      console.log(`Expired job removed: ${jobId}`);
    }
  }
}, 60 * 1000); // Check every minute

// Rate limiting for watermark endpoint (10 requests per minute per API key)
const watermarkLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 10,
  keyGenerator: (req) => req.headers['x-api-key'] || req.ip,
  handler: (req, res) => {
    res.status(429).json({ error: 'Too many requests. Please try again later.' });
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiting for detect endpoint (10 requests per minute per API key)
const detectLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 10,
  keyGenerator: (req) => req.headers['x-api-key'] || req.ip,
  handler: (req, res) => {
    res.status(429).json({ error: 'Too many requests. Please try again later.' });
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Configure multer for file uploads
const upload = multer({
  dest: '/tmp/uploads/',
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['image/png', 'image/jpeg'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only PNG and JPG images are allowed.'));
    }
  }
});

// Configure multer for detection (two files: original and watermarked)
const uploadDetect = multer({
  dest: '/tmp/uploads/',
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB limit per file
  },
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['image/png', 'image/jpeg'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only PNG and JPG images are allowed.'));
    }
  }
});

// Helper to safely delete a file if it exists
function safeUnlink(filePath, jobId = null) {
  if (filePath && fs.existsSync(filePath)) {
    try {
      fs.unlinkSync(filePath);
    } catch (err) {
      const prefix = jobId ? `[${jobId}] ` : '';
      console.error(`${prefix}Error cleaning up file ${filePath}:`, err);
    }
  }
}

// Helper to clean up uploaded files from a request
function cleanupUploadedFiles(req, jobId = null) {
  // Single file upload (e.g., /watermark endpoint)
  if (req.file && req.file.path) {
    safeUnlink(req.file.path, jobId);
  }
  // Multiple file upload (e.g., /detect endpoint)
  if (req.files) {
    Object.values(req.files).flat().forEach(f => {
      if (f && f.path) {
        safeUnlink(f.path, jobId);
      }
    });
  }
}

// Timing-safe string comparison to prevent timing attacks
function timingSafeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') {
    return false;
  }
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) {
    // Compare against itself to maintain constant time even when lengths differ
    crypto.timingSafeEqual(bufA, bufA);
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

// API key authentication middleware
function authenticateApiKey(req, res, next) {
  const apiKey = req.headers['x-api-key'];

  if (!apiKey) {
    return res.status(401).json({ error: 'Missing X-API-Key header' });
  }

  if (!timingSafeEqual(apiKey, API_KEY)) {
    return res.status(401).json({ error: 'Invalid API key' });
  }

  next();
}

// Health check endpoint (no auth required)
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Parse progress from C++ marking binary stdout
function parseMarkProgress(line) {
  if (!line.startsWith('PROGRESS:')) {
    return null;
  }

  const parts = line.substring(9).split(':');
  const step = parts[0];

  if (step === 'loading') {
    return { progress: 'Loading image...', percent: 10 };
  } else if (step === 'marking') {
    const current = parseInt(parts[1], 10);
    const total = parseInt(parts[2], 10);
    const percent = Math.round(10 + (current / total) * 70);
    return { progress: `Embedding watermark (${current}/${total})`, percent };
  } else if (step === 'saving') {
    return { progress: 'Compressing image...', percent: 90 };
  }

  return null;
}

// Parse progress from C++ detection binary stdout
function parseDetectProgress(line) {
  if (!line.startsWith('PROGRESS:')) {
    return null;
  }

  const msg = line.substring(9).trim();

  // Parse "Extracting watermark from frequency domain..."
  if (msg.includes('Extracting watermark')) {
    return { progress: msg, percent: 20 };
  }

  // Parse "Analyzing sequence N..." - estimate progress based on sequence number
  // Typical messages have 5-15 characters, so sequences usually go up to ~10-15
  const seqMatch = msg.match(/Analyzing sequence (\d+)/);
  if (seqMatch) {
    const seqNum = parseInt(seqMatch[1], 10);
    // Progress from 30% to 90% based on sequence (assume max ~15 sequences)
    const percent = Math.min(90, 30 + seqNum * 4);
    return { progress: msg, percent };
  }

  // Default for other progress messages
  return { progress: msg, percent: 50 };
}

// Watermark endpoint with SSE streaming
app.post('/watermark', watermarkLimiter, authenticateApiKey, upload.single('image'), async (req, res) => {
  // Validate required fields
  if (!req.file) {
    return res.status(400).json({ error: 'Missing required field: image' });
  }

  if (!req.body.message) {
    cleanupUploadedFiles(req);
    return res.status(400).json({ error: 'Missing required field: message' });
  }

  const message = req.body.message;
  const strength = parseInt(req.body.strength, 10) || DEFAULT_STRENGTH;

  // Validate strength range
  if (strength < 1 || strength > 100) {
    cleanupUploadedFiles(req);
    return res.status(400).json({ error: 'Strength must be between 1 and 100' });
  }

  const jobId = uuidv4();
  const inputPath = req.file.path;
  const imageName = req.file.originalname || 'image';

  // Set up SSE response
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no'); // Disable nginx buffering
  res.flushHeaders();

  // Helper to send SSE event
  const sendEvent = (data) => {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  console.log(`Starting watermark job ${jobId}: message="${message}", strength=${strength}`);

  // Spawn the mark-image binary
  const markProcess = spawn('./mark-image', [
    inputPath,
    imageName,
    message,
    String(strength)
  ]);

  let lastProgress = null;

  markProcess.stdout.on('data', (data) => {
    const lines = data.toString().split('\n').filter(line => line.trim());
    for (const line of lines) {
      console.log(`[${jobId}] Mark output:`, line);
      const progressData = parseMarkProgress(line);
      if (progressData && JSON.stringify(progressData) !== JSON.stringify(lastProgress)) {
        lastProgress = progressData;
        sendEvent(progressData);
      }
    }
  });

  markProcess.stderr.on('data', (data) => {
    console.error(`[${jobId}] Mark stderr:`, data.toString());
  });

  markProcess.on('close', (code) => {
    // Clean up input file
    safeUnlink(inputPath, jobId);

    if (code === 0) {
      const markedImagePath = `${inputPath}-marked.png`;

      if (fs.existsSync(markedImagePath)) {
        // Store job for download
        jobs.set(jobId, {
          markedImagePath,
          createdAt: Date.now()
        });

        console.log(`[${jobId}] Watermarking complete, file: ${markedImagePath}`);
        sendEvent({ complete: true, downloadUrl: `/download/${jobId}` });
      } else {
        console.error(`[${jobId}] Marked image not found at expected path`);
        sendEvent({ error: 'Processing completed but output file not found' });
      }
    } else {
      console.error(`[${jobId}] mark-image exited with code ${code}`);
      sendEvent({ error: 'Processing failed' });
    }

    res.end();
  });

  markProcess.on('error', (err) => {
    console.error(`[${jobId}] Process error:`, err);
    sendEvent({ error: 'Failed to start processing' });
    res.end();
    safeUnlink(inputPath, jobId);
  });

  // Handle client disconnect
  req.on('close', () => {
    if (!markProcess.killed) {
      console.log(`[${jobId}] Client disconnected, killing process`);
      markProcess.kill();
    }
  });
});

// Detection endpoint with SSE streaming
// Requires both original (unwatermarked) image and watermarked image
app.post('/detect', detectLimiter, authenticateApiKey, uploadDetect.fields([
  { name: 'original', maxCount: 1 },
  { name: 'watermarked', maxCount: 1 }
]), async (req, res) => {
  // Validate required fields
  if (!req.files || !req.files.original || !req.files.original[0]) {
    cleanupUploadedFiles(req);
    return res.status(400).json({ error: 'Missing required field: original (the unwatermarked image)' });
  }

  if (!req.files.watermarked || !req.files.watermarked[0]) {
    cleanupUploadedFiles(req);
    return res.status(400).json({ error: 'Missing required field: watermarked (the watermarked image to detect)' });
  }

  const jobId = uuidv4();
  const originalPath = req.files.original[0].path;
  const watermarkedPath = req.files.watermarked[0].path;
  const outputJsonPath = `/tmp/${jobId}.json`;

  // Set up SSE response
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no'); // Disable nginx buffering
  res.flushHeaders();

  // Helper to send SSE event
  const sendEvent = (data) => {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  console.log(`Starting detection job ${jobId}`);
  sendEvent({ progress: 'Loading images...', percent: 10 });

  // Spawn the detect-image binary
  // Arguments: uid, originalFilePath, markedFilePath
  const detectProcess = spawn('./detect-image', [
    jobId,
    originalPath,
    watermarkedPath
  ]);

  let lastProgress = null;

  detectProcess.stdout.on('data', (data) => {
    const lines = data.toString().split('\n').filter(line => line.trim());
    for (const line of lines) {
      console.log(`[${jobId}] Detect output:`, line);
      const progressData = parseDetectProgress(line);
      if (progressData && JSON.stringify(progressData) !== JSON.stringify(lastProgress)) {
        lastProgress = progressData;
        sendEvent(progressData);
      }
    }
  });

  detectProcess.stderr.on('data', (data) => {
    console.error(`[${jobId}] Detect stderr:`, data.toString());
  });

  detectProcess.on('close', (code) => {
    // Clean up input and output files
    const cleanupFiles = () => {
      safeUnlink(originalPath, jobId);
      safeUnlink(watermarkedPath, jobId);
      safeUnlink(outputJsonPath, jobId);
    };

    if (code === 0) {
      // Read the results JSON
      if (fs.existsSync(outputJsonPath)) {
        try {
          const results = JSON.parse(fs.readFileSync(outputJsonPath, 'utf8'));
          console.log(`[${jobId}] Detection complete:`, results.message);

          sendEvent({
            complete: true,
            detected: results.detected || false,
            message: results.message || null,
            confidence: results.confidence || 0,
            // Include additional stats if available
            statistics: {
              imageWidth: results.imageWidth,
              imageHeight: results.imageHeight,
              primeSize: results.primeSize,
              threshold: results.threshold,
              timing: results.timing,
              totalSequencesTested: results.totalSequencesTested,
              sequencesAboveThreshold: results.sequencesAboveThreshold,
              psnrStats: results.psnrStats,
              correlationStats: results.correlationStats
            }
          });
        } catch (parseErr) {
          console.error(`[${jobId}] Error parsing results:`, parseErr);
          sendEvent({ error: 'Failed to parse detection results' });
        }
      } else {
        console.error(`[${jobId}] Results file not found at expected path`);
        sendEvent({ error: 'Processing completed but results file not found' });
      }
    } else {
      console.error(`[${jobId}] detect-image exited with code ${code}`);
      sendEvent({ error: 'Detection processing failed' });
    }

    cleanupFiles();
    res.end();
  });

  detectProcess.on('error', (err) => {
    console.error(`[${jobId}] Process error:`, err);
    sendEvent({ error: 'Failed to start detection processing' });
    res.end();
    safeUnlink(originalPath, jobId);
    safeUnlink(watermarkedPath, jobId);
  });

  // Handle client disconnect
  req.on('close', () => {
    if (!detectProcess.killed) {
      console.log(`[${jobId}] Client disconnected, killing process`);
      detectProcess.kill();
    }
  });
});

// Download endpoint
app.get('/download/:jobId', authenticateApiKey, (req, res) => {
  const jobId = req.params.jobId;
  const job = jobs.get(jobId);

  if (!job) {
    return res.status(404).json({ error: 'Job not found or expired' });
  }

  if (!fs.existsSync(job.markedImagePath)) {
    jobs.delete(jobId);
    return res.status(404).json({ error: 'File not found' });
  }

  res.setHeader('Content-Type', 'image/png');
  res.setHeader('Content-Disposition', `attachment; filename="watermarked-${jobId}.png"`);

  const fileStream = fs.createReadStream(job.markedImagePath);
  fileStream.pipe(res);

  fileStream.on('error', (err) => {
    console.error(`Error streaming file for job ${jobId}:`, err);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Error reading file' });
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);

  // Clean up any uploaded files on error
  cleanupUploadedFiles(req);

  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 50MB.' });
    }
    return res.status(400).json({ error: err.message });
  }

  res.status(500).json({ error: err.message || 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Watermarking API server running on port ${PORT}`);
});
