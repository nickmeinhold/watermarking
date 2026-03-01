// server.js
// Watermarking REST API with SSE progress streaming

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const { v4: uuidv4 } = require('uuid');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// On Cloud Run, uses Application Default Credentials automatically.
// Locally, set GOOGLE_APPLICATION_CREDENTIALS to a service account key file.
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});
const db = admin.firestore();

const BUCKET_NAME = process.env.GCS_BUCKET || 'watermarking-4a428.firebasestorage.app';
const bucket = admin.storage().bucket(BUCKET_NAME);

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
  methods: ['GET', 'POST', 'DELETE'],
  allowedHeaders: ['Content-Type', 'X-API-Key', 'Authorization'],
  exposedHeaders: ['Content-Disposition'],
};
app.use(cors(corsOptions));

// Parse JSON bodies for GCS endpoints
app.use(express.json());

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

// Firebase Auth ID token verification middleware (for web/mobile clients)
async function authenticateFirebaseToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const idToken = authHeader.substring(7);
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    req.uid = decoded.uid;
    next();
  } catch (err) {
    console.error('Firebase token verification failed:', err.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

// GCS helpers
async function gcsDownload(gcsPath, localPath) {
  const dir = path.dirname(localPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  await bucket.file(gcsPath).download({ destination: localPath });
}

async function gcsUpload(localPath, gcsPath) {
  await bucket.upload(localPath, {
    destination: gcsPath,
    metadata: { cacheControl: 'public, max-age=31536000' },
  });
}

async function gcsSignedUrl(gcsPath) {
  const [url] = await bucket.file(gcsPath).getSignedUrl({
    action: 'read',
    expires: Date.now() + 10 * 365 * 24 * 60 * 60 * 1000, // 10 years
  });
  return url;
}

async function gcsDelete(gcsPath) {
  try {
    await bucket.file(gcsPath).delete();
  } catch (err) {
    if (err.code === 404) {
      console.log(`File ${gcsPath} not found, ignoring delete.`);
    } else {
      throw err;
    }
  }
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

// GCS-based watermark endpoint (for web/mobile clients)
// Server downloads from GCS, processes, uploads result, writes Firestore.
app.post('/watermark/gcs', watermarkLimiter, authenticateFirebaseToken, async (req, res) => {
  const { originalImageId, imagePath, imageName, message, strength: rawStrength } = req.body;
  const userId = req.uid;

  if (!imagePath || !imageName || !message) {
    return res.status(400).json({ error: 'Missing required fields: imagePath, imageName, message' });
  }

  const strength = parseInt(rawStrength, 10) || DEFAULT_STRENGTH;
  if (strength < 1 || strength > 100) {
    return res.status(400).json({ error: 'Strength must be between 1 and 100' });
  }

  const jobId = uuidv4();

  // Set up SSE response
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  res.flushHeaders();

  const sendEvent = (data) => {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  let markedRef;
  let markProcess;
  const tempDir = `/tmp/${jobId}`;

  try {
    // 1. Create markedImages placeholder in Firestore
    markedRef = await db.collection('markedImages').add({
      originalImageId: originalImageId || null,
      userId,
      message,
      name: imageName,
      strength,
      progress: 'Downloading image...',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    sendEvent({ progress: 'Downloading image...', percent: 5 });

    // 2. Download original from GCS
    const localInput = `${tempDir}/${imageName}`;
    await gcsDownload(imagePath, localInput);

    console.log(`[${jobId}] Starting GCS watermark: message="${message}", strength=${strength}`);
    sendEvent({ progress: 'Loading image...', percent: 10 });
    await markedRef.update({ progress: 'Loading image...' });

    // 3. Run C++ binary
    markProcess = spawn('./mark-image', [localInput, imageName, message, String(strength)]);

    let lastProgress = null;

    markProcess.stdout.on('data', (data) => {
      const lines = data.toString().split('\n').filter(l => l.trim());
      for (const line of lines) {
        console.log(`[${jobId}] Mark output:`, line);
        const progressData = parseMarkProgress(line);
        if (progressData && JSON.stringify(progressData) !== JSON.stringify(lastProgress)) {
          lastProgress = progressData;
          sendEvent(progressData);
          markedRef.update({ progress: progressData.progress }).catch(() => {});
        }
      }
    });

    markProcess.stderr.on('data', (data) => {
      console.error(`[${jobId}] Mark stderr:`, data.toString());
    });

    // Handle client disconnect
    req.on('close', () => {
      if (markProcess && !markProcess.killed) {
        console.log(`[${jobId}] Client disconnected, killing process`);
        markProcess.kill();
      }
    });

    // Wait for process to complete
    const exitCode = await new Promise((resolve, reject) => {
      markProcess.on('close', resolve);
      markProcess.on('error', reject);
    });

    if (exitCode !== 0) {
      throw new Error(`mark-image exited with code ${exitCode}`);
    }

    const markedFilePath = `${localInput}-marked.png`;
    if (!fs.existsSync(markedFilePath)) {
      throw new Error('Processing completed but output file not found');
    }

    // 4. Upload marked image to GCS
    sendEvent({ progress: 'Uploading marked image...', percent: 92 });
    await markedRef.update({ progress: 'Uploading marked image...' });

    const timestamp = Date.now();
    const baseName = imageName.replace(/\.[^/.]+$/, '');
    const markedGcsPath = `marked-images/${userId}/${timestamp}/${baseName}.png`;
    await gcsUpload(markedFilePath, markedGcsPath);

    // 5. Generate signed URL
    sendEvent({ progress: 'Generating URL...', percent: 96 });
    await markedRef.update({ progress: 'Generating URL...' });
    const servingUrl = await gcsSignedUrl(markedGcsPath);

    // 6. Update Firestore (null progress = complete)
    await markedRef.update({
      path: markedGcsPath,
      servingUrl,
      progress: null,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    sendEvent({ complete: true, markedImageId: markedRef.id });
    console.log(`[${jobId}] GCS watermark complete: ${markedRef.id}`);
  } catch (err) {
    console.error(`[${jobId}] GCS watermark error:`, err);
    sendEvent({ error: err.message || 'Processing failed' });
    // Clear progress on error
    if (markedRef) {
      await markedRef.update({ progress: null }).catch(() => {});
    }
  } finally {
    // Cleanup temp files
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
    res.end();
  }
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

// GCS-based detection endpoint (for web/mobile clients)
// Server downloads both images from GCS, runs detection, writes results to Firestore.
app.post('/detect/gcs', detectLimiter, authenticateFirebaseToken, async (req, res) => {
  const { originalImageId, markedImageId, originalPath, markedPath } = req.body;
  const userId = req.uid;

  if (!originalPath || !markedPath) {
    return res.status(400).json({ error: 'Missing required fields: originalPath, markedPath' });
  }

  const jobId = uuidv4();

  // Set up SSE response
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  res.flushHeaders();

  const sendEvent = (data) => {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  const tempDir = `/tmp/${jobId}`;
  let detectProcess;

  try {
    // 1. Download both images from GCS
    sendEvent({ progress: 'Downloading images...', percent: 5 });

    const localOriginal = `${tempDir}/original`;
    const localMarked = `${tempDir}/marked`;
    await Promise.all([
      gcsDownload(originalPath, localOriginal),
      gcsDownload(markedPath, localMarked),
    ]);

    sendEvent({ progress: 'Loading images...', percent: 10 });
    console.log(`[${jobId}] Starting GCS detection`);

    // 2. Run C++ detect binary
    const outputJsonPath = `/tmp/${jobId}.json`;
    detectProcess = spawn('./detect-image', [jobId, localOriginal, localMarked]);

    let lastProgress = null;

    detectProcess.stdout.on('data', (data) => {
      const lines = data.toString().split('\n').filter(l => l.trim());
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

    // Handle client disconnect
    req.on('close', () => {
      if (detectProcess && !detectProcess.killed) {
        console.log(`[${jobId}] Client disconnected, killing process`);
        detectProcess.kill();
      }
    });

    // Wait for process
    const exitCode = await new Promise((resolve, reject) => {
      detectProcess.on('close', resolve);
      detectProcess.on('error', reject);
    });

    if (exitCode !== 0) {
      throw new Error(`detect-image exited with code ${exitCode}`);
    }

    if (!fs.existsSync(outputJsonPath)) {
      throw new Error('Processing completed but results file not found');
    }

    const results = JSON.parse(fs.readFileSync(outputJsonPath, 'utf8'));
    safeUnlink(outputJsonPath, jobId);

    // 3. Generate signed URLs for both images
    let extractedServingUrl = null;
    let originalServingUrl = null;
    try { extractedServingUrl = await gcsSignedUrl(markedPath); } catch (_) {}
    try { originalServingUrl = await gcsSignedUrl(originalPath); } catch (_) {}

    // 4. Write detection result to Firestore
    // Use markedImageId as doc ID if provided, otherwise auto-generate
    const detectionRef = markedImageId
      ? db.collection('detectionItems').doc(markedImageId)
      : db.collection('detectionItems').doc();

    const detectionItem = {
      userId,
      originalImageId: originalImageId || null,
      markedImageId: markedImageId || null,
      result: results.message ? `Watermark Detected: ${results.message}` : 'No message found.',
      confidence: results.confidence || 0,
      detected: results.detected || false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      progress: '100',
      pathOriginal: originalPath,
      pathMarked: markedPath,
      servingUrl: extractedServingUrl,
      originalRef: {
        remotePath: originalPath,
        servingUrl: originalServingUrl,
      },
      extractedRef: {
        remotePath: markedPath,
        servingUrl: extractedServingUrl,
      },
      isCaptured: false,
      // Extended statistics
      imageWidth: results.imageWidth || null,
      imageHeight: results.imageHeight || null,
      primeSize: results.primeSize || null,
      threshold: results.threshold || 6.0,
      timing: results.timing || null,
      totalSequencesTested: results.totalSequencesTested || 0,
      sequencesAboveThreshold: results.sequencesAboveThreshold || 0,
      psnrStats: results.psnrStats || null,
      sequences: results.sequences || [],
      correlationStats: results.correlationStats || null,
      rawResult: results,
    };

    await detectionRef.set(detectionItem);

    sendEvent({
      complete: true,
      detected: results.detected || false,
      message: results.message || null,
      confidence: results.confidence || 0,
      detectionItemId: detectionRef.id,
    });

    console.log(`[${jobId}] GCS detection complete: ${detectionRef.id}`);
  } catch (err) {
    console.error(`[${jobId}] GCS detection error:`, err);
    sendEvent({ error: err.message || 'Detection failed' });
  } finally {
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
    res.end();
  }
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

// Delete an original image + all marked versions + detection items + GCS files
app.delete('/original/:id', authenticateFirebaseToken, async (req, res) => {
  const originalImageId = req.params.id;
  const userId = req.uid;

  try {
    const originalRef = db.collection('originalImages').doc(originalImageId);
    const originalDoc = await originalRef.get();

    if (!originalDoc.exists) {
      return res.status(404).json({ error: 'Original image not found' });
    }

    // Verify ownership
    const originalData = originalDoc.data();
    if (originalData.userId !== userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Delete all marked images referencing this original
    const markedSnap = await db.collection('markedImages')
      .where('originalImageId', '==', originalImageId)
      .get();

    for (const markedDoc of markedSnap.docs) {
      const markedData = markedDoc.data();

      // Delete detection items referencing this marked image
      const detSnap = await db.collection('detectionItems')
        .where('markedImageId', '==', markedDoc.id)
        .get();
      for (const detDoc of detSnap.docs) {
        const detData = detDoc.data();
        if (detData.pathMarked) await gcsDelete(detData.pathMarked).catch(() => {});
        await detDoc.ref.delete();
      }

      if (markedData.path) await gcsDelete(markedData.path).catch(() => {});
      await markedDoc.ref.delete();
    }

    // Delete the original GCS file
    if (originalData.path) await gcsDelete(originalData.path).catch(() => {});

    await originalRef.delete();
    res.json({ ok: true });
  } catch (err) {
    console.error('Delete original error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Delete a marked image + related detection items + GCS files
app.delete('/marked/:id', authenticateFirebaseToken, async (req, res) => {
  const markedImageId = req.params.id;
  const userId = req.uid;

  try {
    const markedRef = db.collection('markedImages').doc(markedImageId);
    const markedDoc = await markedRef.get();

    if (!markedDoc.exists) {
      return res.status(404).json({ error: 'Marked image not found' });
    }

    const markedData = markedDoc.data();
    if (markedData.userId !== userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Delete detection items referencing this marked image
    const detSnap = await db.collection('detectionItems')
      .where('markedImageId', '==', markedImageId)
      .get();
    for (const detDoc of detSnap.docs) {
      const detData = detDoc.data();
      if (detData.pathMarked) await gcsDelete(detData.pathMarked).catch(() => {});
      await detDoc.ref.delete();
    }

    // Delete the marked image GCS file
    if (markedData.path) await gcsDelete(markedData.path).catch(() => {});

    await markedRef.delete();
    res.json({ ok: true });
  } catch (err) {
    console.error('Delete marked error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Delete a detection item + GCS file
app.delete('/detection/:id', authenticateFirebaseToken, async (req, res) => {
  const detectionItemId = req.params.id;
  const userId = req.uid;

  try {
    const detRef = db.collection('detectionItems').doc(detectionItemId);
    const detDoc = await detRef.get();

    if (!detDoc.exists) {
      return res.status(404).json({ error: 'Detection item not found' });
    }

    const detData = detDoc.data();
    if (detData.userId !== userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (detData.pathMarked) await gcsDelete(detData.pathMarked).catch(() => {});

    await detRef.delete();
    res.json({ ok: true });
  } catch (err) {
    console.error('Delete detection error:', err);
    res.status(500).json({ error: err.message });
  }
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
