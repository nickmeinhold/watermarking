// Detection endpoints: POST /detect (direct upload) and POST /detect/gcs (GCS-based)

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { spawn } = require('child_process');
const fs = require('fs');

const { admin, db, PROCESS_TIMEOUT_MS } = require('../config');
const { authenticateApiKey, authenticateFirebaseToken } = require('../auth');
const { gcsDownload, gcsSignedUrl } = require('../gcs');
const { safeUnlink, cleanupUploadedFiles, parseDetectProgress } = require('../helpers');

/// Creates the detection router. Accepts a multer instance for direct file uploads.
module.exports = function createRouter(uploadDetect) {
  const router = express.Router();

  const uploadFields = uploadDetect.fields([
    { name: 'original', maxCount: 1 },
    { name: 'watermarked', maxCount: 1 },
  ]);

  /// Direct file upload detection with SSE streaming.
  /// Requires both original (unwatermarked) image and watermarked image.
  router.post('/', authenticateApiKey, uploadFields, (req, res) => {
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

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();

    const sendEvent = (data) => {
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    };

    console.log(`Starting detection job ${jobId}`);
    sendEvent({ progress: 'Loading images...', percent: 10 });

    const detectProcess = spawn('./detect-image', [jobId, originalPath, watermarkedPath]);

    const processTimeout = setTimeout(() => {
      if (!detectProcess.killed) {
        detectProcess.kill('SIGKILL');
        console.error(`[${jobId}] Process killed: exceeded ${PROCESS_TIMEOUT_MS / 1000}s timeout`);
        sendEvent({ error: 'Detection timed out' });
        res.end();
      }
    }, PROCESS_TIMEOUT_MS);

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
      clearTimeout(processTimeout);

      const cleanupFiles = () => {
        safeUnlink(originalPath, jobId);
        safeUnlink(watermarkedPath, jobId);
        safeUnlink(outputJsonPath, jobId);
      };

      if (code === 0) {
        if (fs.existsSync(outputJsonPath)) {
          try {
            const results = JSON.parse(fs.readFileSync(outputJsonPath, 'utf8'));
            console.log(`[${jobId}] Detection complete:`, results.message);

            sendEvent({
              complete: true,
              detected: results.detected || false,
              message: results.message || null,
              confidence: results.confidence || 0,
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
      clearTimeout(processTimeout);
      console.error(`[${jobId}] Process error:`, err);
      sendEvent({ error: 'Failed to start detection processing' });
      res.end();
      safeUnlink(originalPath, jobId);
      safeUnlink(watermarkedPath, jobId);
    });

    req.on('close', () => {
      if (!detectProcess.killed) {
        clearTimeout(processTimeout);
        console.log(`[${jobId}] Client disconnected, killing process`);
        detectProcess.kill();
      }
    });
  });

  /// GCS-based detection endpoint (for web/mobile clients).
  /// Server downloads both images from GCS, runs detection, writes results to Firestore.
  router.post('/gcs', authenticateFirebaseToken, async (req, res) => {
    const { originalImageId, markedImageId, originalPath, markedPath } = req.body;
    const userId = req.uid;

    if (!originalPath || !markedPath) {
      return res.status(400).json({ error: 'Missing required fields: originalPath, markedPath' });
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

    const tempDir = `/tmp/${jobId}`;
    let detectProcess;

    try {
      sendEvent({ progress: 'Downloading images...', percent: 5 });

      const localOriginal = `${tempDir}/original`;
      const localMarked = `${tempDir}/marked`;
      await Promise.all([
        gcsDownload(originalPath, localOriginal),
        gcsDownload(markedPath, localMarked),
      ]);

      sendEvent({ progress: 'Loading images...', percent: 10 });
      console.log(`[${jobId}] Starting GCS detection`);

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

      req.on('close', () => {
        if (detectProcess && !detectProcess.killed) {
          console.log(`[${jobId}] Client disconnected, killing process`);
          detectProcess.kill();
        }
      });

      // Wait for process (with timeout)
      const exitCode = await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          if (detectProcess && !detectProcess.killed) {
            detectProcess.kill('SIGKILL');
          }
          reject(new Error(`Process timed out after ${PROCESS_TIMEOUT_MS / 1000}s`));
        }, PROCESS_TIMEOUT_MS);
        detectProcess.on('close', (code) => { clearTimeout(timeout); resolve(code); });
        detectProcess.on('error', (err) => { clearTimeout(timeout); reject(err); });
      });

      if (exitCode !== 0) {
        throw new Error(`detect-image exited with code ${exitCode}`);
      }

      if (!fs.existsSync(outputJsonPath)) {
        throw new Error('Processing completed but results file not found');
      }

      const results = JSON.parse(fs.readFileSync(outputJsonPath, 'utf8'));
      safeUnlink(outputJsonPath, jobId);

      // Generate signed URLs for both images
      let extractedServingUrl = null;
      let originalServingUrl = null;
      try { extractedServingUrl = await gcsSignedUrl(markedPath); } catch (_) {}
      try { originalServingUrl = await gcsSignedUrl(originalPath); } catch (_) {}

      // Write detection result to Firestore
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

  return router;
};
