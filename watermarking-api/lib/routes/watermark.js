// Watermark endpoints: POST /watermark (direct upload) and POST /watermark/gcs (GCS-based)

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { spawn } = require('child_process');
const fs = require('fs');

const { admin, db, DEFAULT_STRENGTH, PROCESS_TIMEOUT_MS } = require('../config');
const { authenticateApiKey, authenticateFirebaseToken } = require('../auth');
const { gcsDownload, gcsUpload, gcsSignedUrl } = require('../gcs');
const { safeUnlink, cleanupUploadedFiles, parseMarkProgress } = require('../helpers');
const { jobs } = require('../jobs');

/// Creates the watermark router. Accepts a multer instance for direct file uploads.
module.exports = function createRouter(upload) {
  const router = express.Router();

  /// Direct file upload watermark with SSE streaming.
  /// Used by external API consumers with API key auth.
  router.post('/', authenticateApiKey, upload.single('image'), (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'Missing required field: image' });
    }

    if (!req.body.message) {
      cleanupUploadedFiles(req);
      return res.status(400).json({ error: 'Missing required field: message' });
    }

    const message = req.body.message;
    const strength = parseInt(req.body.strength, 10) || DEFAULT_STRENGTH;

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
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();

    const sendEvent = (data) => {
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    };

    console.log(`Starting watermark job ${jobId}: message="${message}", strength=${strength}`);

    const markProcess = spawn('./mark-image', [inputPath, imageName, message, String(strength)]);

    const processTimeout = setTimeout(() => {
      if (!markProcess.killed) {
        markProcess.kill('SIGKILL');
        console.error(`[${jobId}] Process killed: exceeded ${PROCESS_TIMEOUT_MS / 1000}s timeout`);
        sendEvent({ error: 'Processing timed out' });
        res.end();
      }
    }, PROCESS_TIMEOUT_MS);

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
      clearTimeout(processTimeout);
      safeUnlink(inputPath, jobId);

      if (code === 0) {
        const markedImagePath = `${inputPath}-marked.png`;

        if (fs.existsSync(markedImagePath)) {
          jobs.set(jobId, { markedImagePath, createdAt: Date.now() });
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
      clearTimeout(processTimeout);
      console.error(`[${jobId}] Process error:`, err);
      sendEvent({ error: 'Failed to start processing' });
      res.end();
      safeUnlink(inputPath, jobId);
    });

    req.on('close', () => {
      if (!markProcess.killed) {
        clearTimeout(processTimeout);
        console.log(`[${jobId}] Client disconnected, killing process`);
        markProcess.kill();
      }
    });
  });

  /// GCS-based watermark endpoint (for web/mobile clients).
  /// Server downloads from GCS, processes, uploads result, writes Firestore.
  router.post('/gcs', authenticateFirebaseToken, async (req, res) => {
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

      const localInput = `${tempDir}/${imageName}`;
      await gcsDownload(imagePath, localInput);

      console.log(`[${jobId}] Starting GCS watermark: message="${message}", strength=${strength}`);
      sendEvent({ progress: 'Loading image...', percent: 10 });
      await markedRef.update({ progress: 'Loading image...' });

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

      req.on('close', () => {
        if (markProcess && !markProcess.killed) {
          console.log(`[${jobId}] Client disconnected, killing process`);
          markProcess.kill();
        }
      });

      // Wait for process to complete (with timeout)
      const exitCode = await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          if (markProcess && !markProcess.killed) {
            markProcess.kill('SIGKILL');
          }
          reject(new Error(`Process timed out after ${PROCESS_TIMEOUT_MS / 1000}s`));
        }, PROCESS_TIMEOUT_MS);
        markProcess.on('close', (code) => { clearTimeout(timeout); resolve(code); });
        markProcess.on('error', (err) => { clearTimeout(timeout); reject(err); });
      });

      if (exitCode !== 0) {
        throw new Error(`mark-image exited with code ${exitCode}`);
      }

      const markedFilePath = `${localInput}-marked.png`;
      if (!fs.existsSync(markedFilePath)) {
        throw new Error('Processing completed but output file not found');
      }

      sendEvent({ progress: 'Uploading marked image...', percent: 92 });
      await markedRef.update({ progress: 'Uploading marked image...' });

      const timestamp = Date.now();
      const baseName = imageName.replace(/\.[^/.]+$/, '');
      const markedGcsPath = `marked-images/${userId}/${timestamp}/${baseName}.png`;
      await gcsUpload(markedFilePath, markedGcsPath);

      sendEvent({ progress: 'Generating URL...', percent: 96 });
      await markedRef.update({ progress: 'Generating URL...' });
      const servingUrl = await gcsSignedUrl(markedGcsPath);

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
      if (markedRef) {
        await markedRef.delete().catch(() => {});
      }
    } finally {
      if (fs.existsSync(tempDir)) {
        fs.rmSync(tempDir, { recursive: true, force: true });
      }
      res.end();
    }
  });

  return router;
};
