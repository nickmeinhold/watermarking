// detection-queues.js
// ===================
// Detection task processing for Firestore-based queue

var firebaseAdminSingleton = require('./firebase-admin-singleton');
var db = firebaseAdminSingleton.getFirestore();

var execFile = require('child_process').execFile;
var fs = require('fs');
var { promisify } = require('util');
var execFileAsync = promisify(execFile);


var storageHelper = require('./storage-helper');

// Promisify storage helper
function downloadFileAsync(gcsPath, localPath) {
  return new Promise((resolve, reject) => {
    storageHelper.downloadFile(gcsPath, localPath, (error) => {
      if (error) reject(error);
      else resolve();
    });
  });
}

// Helper to update detecting progress
async function updateProgress(userId, updates) {
  await db.collection('detecting').doc(userId).set(updates, { merge: true });
}

module.exports = {
  /**
   * Process a complete detection task:
   * 1. Download original image from GCS
   * 2. Download marked image from GCS
   * 3. Run detect-wm binary
   * 4. Update Firestore with results
   */
  processDetectionTask: async function (taskId, data) {
    console.log(`Processing detection task for user: ${data.userId}`);

    var originalPath = '/tmp/' + taskId + '/original';
    var markedPath = '/tmp/' + taskId + '/marked';

    try {
      // Step 1 & 2: Download images in parallel
      await updateProgress(data.userId, {
        progress: 'Server has received request, downloading images from storage...',
        isDetecting: true
      });

      console.log('Downloading images...');
      console.log('Downloading original image from:', data.pathOriginal);
      console.log('Downloading marked image from:', data.pathMarked);

      await Promise.all([
        downloadFileAsync(data.pathOriginal, originalPath).then(() => console.log('Downloaded original image.')),
        downloadFileAsync(data.pathMarked, markedPath).then(() => console.log('Downloaded marked image.'))
      ]);

      // Step 3: Run detection
      await updateProgress(data.userId, {
        progress: 'Server has downloaded both images, now detecting watermarks...'
      });

      console.log('Detecting message...');

      // Run detection binary
      await new Promise((resolve, reject) => {
        execFile('./detect-wm', [taskId, originalPath, markedPath], async (error, stdout, stderr) => {
          const code = error ? error.code : 0;
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

              // Add result to detectionItems collection for history
              await db.collection('detectionItems').add({
                userId: data.userId,
                originalImageId: data.originalImageId || null,
                markedImageId: data.markedImageId || null,
                result: resultsJson.message ? `Watermark Detected: ${resultsJson.message}` : 'Watermark Detected',
                rawResult: resultsJson,
                timestamp: new Date(),
                progress: '100',
                pathOriginal: data.pathOriginal,
                pathMarked: data.pathMarked
              });

              resolve();
            } catch (err) {
              reject(err);
            }
          } else {
            console.error('Detection error:', stderr);
            reject(error || new Error(`Detection failed with code ${code}`));
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
