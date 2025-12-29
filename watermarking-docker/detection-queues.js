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
  processDetectionTask: async function (data) {
    console.log(`Processing detection task for user: ${data.userId}`);

    var originalPath = '/tmp/' + data.userId + '/original';
    var markedPath = '/tmp/' + data.userId + '/marked';

    try {
      // Step 1: Download original image
      await updateProgress(data.userId, {
        progress: 'Server has received request, downloading original image from storage...',
        isDetecting: true
      });

      console.log('Downloading original image from:', data.pathOriginal);
      await downloadFileAsync(data.pathOriginal, originalPath);
      console.log('Downloaded original image.');

      // Step 2: Download marked image
      await updateProgress(data.userId, {
        progress: 'Server downloaded original image, now downloading marked image from storage...'
      });

      console.log('Downloading marked image from:', data.pathMarked);
      await downloadFileAsync(data.pathMarked, markedPath);
      console.log('Downloaded marked image.');

      // Step 3: Run detection
      await updateProgress(data.userId, {
        progress: 'Server has downloaded both images, now detecting watermarks...'
      });

      console.log('Detecting message...');

      // Run detection binary
      await new Promise((resolve, reject) => {
        var child = execFile('./detect-wm', [data.userId, originalPath, markedPath], (error, stdout, stderr) => {
          if (error && error.code !== 0 && error.code !== 254) {
            reject(error);
          }
        });

        child.on('exit', async (code) => {
          console.log('Detection exit code:', code);

          if (code === 254) {
            // Error - different sizes
            console.log('Error - the marked and original images were of different sizes.');
            await updateProgress(data.userId, {
              progress: 'Detection unsuccessful.',
              isDetecting: false,
              error: 'Different sizes for marked and original images'
            });
            reject(new Error('Different sizes for marked and original images'));
          } else if (code === 0) {
            // Success - read results
            var resultsJson = JSON.parse(fs.readFileSync('/tmp/' + data.userId + '.json', 'utf8'));
            console.log('Detected watermark:', resultsJson);

            await updateProgress(data.userId, {
              progress: 'Detection complete.',
              isDetecting: false,
              results: resultsJson
            });

            console.log('Message detected and results saved to database.');
            resolve();
          } else {
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
    }
  }
};
