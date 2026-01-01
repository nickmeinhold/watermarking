// detection-queues.js
// ===================
// Detection task processing for Firestore-based queue

var firebaseAdminSingleton = require('./firebase-admin-singleton');
var db = firebaseAdminSingleton.getFirestore();

var { execFile, spawn } = require('child_process');
var fs = require('fs');
var { promisify } = require('util');
var execFileAsync = promisify(execFile);


var storageHelper = require('./storage-helper');

// Promisify storage helper with progress
function downloadFileAsync(gcsPath, localPath, label, userId) {
  return new Promise((resolve, reject) => {
    let lastUpdate = 0;
    let lastPercent = 0;

    storageHelper.downloadFileWithProgress(gcsPath, localPath, async (percent, downloaded, total) => {
      const now = Date.now();
      // Update every 2 seconds or every 20% change to avoid spamming Firestore
      if ((now - lastUpdate > 2000) || (Math.abs(percent - lastPercent) >= 20)) {
        lastUpdate = now;
        lastPercent = percent;

        try {
          await updateProgress(userId, {
            progress: `Downloading ${label}: ${percent}%`
          });
        } catch (e) {
          // Ignore progress update errors
          console.error('Progress update error:', e);
        }
      }
    }).then(resolve).catch(reject);
  });
}

// Helper to update detecting progress
async function updateProgress(userId, updates) {
  await db.collection('detecting').doc(userId).set(updates, { merge: true });
}

module.exports = {
  processDetectionTask: async function (taskId, data) {
    console.log(`Processing detection task for user: ${data.userId}`);

    var originalPath = '/tmp/' + taskId + '/original';
    var markedPath = '/tmp/' + taskId + '/marked';

    try {
      await updateProgress(data.userId, {
        progress: 'Server has received request, downloading images from storage...',
        isDetecting: true
      });

      console.log('Downloading images...');
      console.log('Downloading original image from:', data.pathOriginal);
      console.log('Downloading marked image from:', data.pathMarked);

      // Download sequentially to provide clear progress for each file
      // (Parallel downloads might confuse the single status string UI)
      await downloadFileAsync(data.pathOriginal, originalPath, 'original image', data.userId);
      console.log('Downloaded original image.');

      await downloadFileAsync(data.pathMarked, markedPath, 'marked image', data.userId);
      console.log('Downloaded marked image.');

      // Step 3: Run detection
      await updateProgress(data.userId, {
        progress: 'Server has downloaded both images, now detecting watermarks...'
      });

      console.log('Detecting message...');

      // Run detection binary
      await new Promise((resolve, reject) => {
        const detectProcess = spawn('./detect-wm', [taskId, originalPath, markedPath]);

        let stdout = '';
        let stderr = '';
        let lastProgressUpdate = 0;

        detectProcess.stdout.on('data', async (chunk) => {
          const str = chunk.toString();
          stdout += str;
          console.log('[detect-wm]', str.trim());

          // Parse progress
          const lines = str.split('\n');
          for (const line of lines) {
            if (line.startsWith('PROGRESS:')) {
              const progressMsg = line.replace('PROGRESS:', '').trim();
              const now = Date.now();
              // Throttle updates to max once per second
              if (now - lastProgressUpdate > 1000) {
                lastProgressUpdate = now;
                updateProgress(data.userId, {
                  progress: progressMsg,
                  isDetecting: true
                }).catch(e => console.error('Progress update error:', e));
              }
            }
          }
        });

        detectProcess.stderr.on('data', (data) => {
          const str = data.toString();
          stderr += str;
          console.error('[detect-wm error]', str);
        });

        detectProcess.on('close', async (code) => {
          console.log('Detection exit code:', code);

          if (code === 254) {
            // Error - different sizes
            console.log('Error - the marked and original images were of different sizes.');

            let errorMessage = 'Different sizes for marked and original images';
            // Try to parse sizes from stdout
            const sizeMatch = stdout.match(/Original: (\d+x\d+), Marked: (\d+x\d+)/);
            if (sizeMatch) {
              errorMessage += ` (${sizeMatch[1]} vs ${sizeMatch[2]})`;
            }

            await updateProgress(data.userId, {
              progress: 'Detection unsuccessful.',
              isDetecting: false,
              error: errorMessage
            });
            reject(new Error(errorMessage));
          } else if (code === 0) {
            // Success - read results
            try {
              var resultsJson = JSON.parse(fs.readFileSync('/tmp/' + taskId + '.json', 'utf8'));
              console.log('Detected watermark:', resultsJson);

              await updateProgress(data.userId, {
                progress: 'Detection complete.',
                isDetecting: false,
                results: resultsJson
              });

              console.log('Message detected and results saved to database.');
              console.log('Result added to detectionItems history.');

              // Generate signed URL for the extracted image
              let servingUrl = null;
              if (data.pathMarked) {
                try {
                  servingUrl = await storageHelper.getSignedUrl(data.pathMarked);
                  console.log('Generated serving URL for extracted image');
                } catch (urlErr) {
                  console.error('Failed to generate serving URL:', urlErr);
                }
              }

              // Add result to detectionItems collection for history
              // Use itemId from client if provided, otherwise auto-generate
              const detectionRef = data.itemId
                ? db.collection('detectionItems').doc(data.itemId)
                : db.collection('detectionItems').doc();

              // Build detection item with extended statistics
              const detectionItem = {
                userId: data.userId,
                originalImageId: data.originalImageId || null,
                markedImageId: data.markedImageId || null,
                result: resultsJson.message ? `Watermark Detected: ${resultsJson.message}` : 'Watermark Detected',
                confidence: resultsJson.confidence || 0,
                detected: resultsJson.detected || false,
                timestamp: new Date(),
                progress: '100',
                pathOriginal: data.pathOriginal,
                pathMarked: data.pathMarked,
                servingUrl: servingUrl,

                // Image properties
                imageWidth: resultsJson.imageWidth || null,
                imageHeight: resultsJson.imageHeight || null,
                primeSize: resultsJson.primeSize || null,
                threshold: resultsJson.threshold || 6.0,

                // Timing breakdown (milliseconds)
                timing: resultsJson.timing || null,

                // Sequence statistics
                totalSequencesTested: resultsJson.totalSequencesTested || 0,
                sequencesAboveThreshold: resultsJson.sequencesAboveThreshold || 0,

                // PSNR summary statistics
                psnrStats: resultsJson.psnrStats || null,

                // Per-sequence details (for charts/histograms)
                sequences: resultsJson.sequences || [],

                // Correlation matrix statistics
                correlationStats: resultsJson.correlationStats || null,

                // Store raw result for backward compatibility
                rawResult: resultsJson
              };

              await detectionRef.set(detectionItem);

              resolve();
            } catch (err) {
              reject(err);
            }
          } else {
            console.error('Detection error:', stderr);
            reject(new Error(`Detection failed with code ${code}`));
          }
        });
      });

    } catch (error) {
      console.error('Detection task failed:', error);
      await updateProgress(data.userId, {
        progress: 'Detection failed.',
        isDetecting: false,
        error: error.message || String(error)
      });
      throw error;
    } finally {
      // Cleanup temporary files
      try {
        const tempDir = '/tmp/' + taskId;
        if (fs.existsSync(tempDir)) {
          fs.rmSync(tempDir, { recursive: true, force: true });
          console.log(`Cleaned up temporary directory: ${tempDir}`);
        }
      } catch (cleanupError) {
        console.error(`Error cleaning up temporary directory: ${cleanupError}`);
      }
    }
  }
};
