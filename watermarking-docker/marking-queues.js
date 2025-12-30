// marking-queues.js
// =================
// Marking task processing for Firestore-based queue

var firebaseAdminSingleton = require('./firebase-admin-singleton');
var db = firebaseAdminSingleton.getFirestore();

var { spawn } = require('child_process');

var storageHelper = require('./storage-helper');

// Promisify storage helper functions
function downloadFileAsync(gcsPath, localPath) {
  return new Promise((resolve, reject) => {
    storageHelper.downloadFile(gcsPath, localPath, (error) => {
      if (error) reject(error);
      else resolve();
    });
  });
}

function uploadFileAsync(localPath, gcsPath) {
  return new Promise((resolve, reject) => {
    storageHelper.uploadFile(localPath, gcsPath, (error) => {
      if (error) reject(error);
      else resolve();
    });
  });
}


// Helper to update progress in Firestore
async function updateProgress(markedImageId, progress) {
  try {
    await db.collection('markedImages').doc(markedImageId).update({ progress });
  } catch (err) {
    console.error('Error updating progress:', err);
  }
}

// Run mark-image binary with real-time progress updates
function runMarkImageWithProgress(filePath, imageName, message, strength, markedImageId) {
  return new Promise((resolve, reject) => {
    const child = spawn('./mark-image', [
      filePath,
      imageName,
      message,
      String(strength)
    ]);

    let markingStartTime = 0;
    let currentMarkingStatus = '';

    child.stdout.on('data', async (data) => {
      const lines = data.toString().split('\n').filter(line => line.trim());
      for (const line of lines) {
        console.log('Mark output:', line);
        if (line.startsWith('PROGRESS:')) {
          const parts = line.substring(9).split(':');
          const step = parts[0];

          let progressText;
          if (step === 'loading') {
            progressText = 'Loading image...';
          } else if (step === 'marking') {
            const current = parseInt(parts[1], 10);
            const total = parseInt(parts[2], 10);

            if (current === 1) {
              markingStartTime = Date.now();
            }

            let etaText = '';
            if (current > 1 && markingStartTime > 0) {
              const elapsed = Date.now() - markingStartTime;
              const stepsDone = current - 1;
              const avgPerStep = elapsed / stepsDone;
              const stepsRemaining = total - stepsDone;
              const etaMs = avgPerStep * stepsRemaining;

              const totalSeconds = Math.round(etaMs / 1000);
              const minutes = Math.floor(totalSeconds / 60);
              const seconds = totalSeconds % 60;

              if (minutes > 0) {
                etaText = ` - ${minutes}m ${seconds}s remaining`;
              } else {
                etaText = ` - ${seconds}s remaining`;
              }
            }

            currentMarkingStatus = `Embedding watermark (${current}/${total})${etaText}`;
            progressText = currentMarkingStatus;
          } else if (step === 'saving') {
            progressText = 'Compressing image...';
          } else if (step === 'dft') {
            progressText = (currentMarkingStatus || 'Processing') + ' - DFT...';
          } else if (step === 'idft') {
            progressText = (currentMarkingStatus || 'Processing') + ' - IDFT...';
          }

          if (progressText) {
            await updateProgress(markedImageId, progressText);
          }
        }
      }
    });

    child.stderr.on('data', (data) => {
      console.error('Mark stderr:', data.toString());
    });

    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`mark-image exited with code ${code}`));
      }
    });

    child.on('error', (err) => {
      reject(err);
    });
  });
}

module.exports = {
  /**
   * Process a complete marking task:
   * 1. Download original image from GCS
   * 2. Run mark-image binary
   * 3. Upload marked image to GCS
   * 4. Update Firestore with result
   */
  processMarkingTask: async function (taskId, data) {
    console.log(`Processing marking task for image: ${data.name}`);

    // Step 1: Download the original image
    var timestamp = String(Date.now());
    var filePath = '/tmp/' + taskId + '/' + data.name;

    await updateProgress(data.markedImageId, 'Downloading image...');
    console.log('Downloading image from:', data.path);
    await downloadFileAsync(data.path, filePath);
    console.log('Downloaded to:', filePath);

    // Step 2: Run the marking binary with progress updates
    console.log(`Marking image with message "${data.message}" at strength ${data.strength}`);
    await runMarkImageWithProgress(
      filePath,
      data.name,
      data.message,
      data.strength,
      data.markedImageId
    );

    // Step 3: Upload the marked image
    var markedFilePath = filePath + '-marked.png';
    var markedGcsPath = 'marked-images/' + data.userId + '/' + timestamp + '/' + data.name + '.png';

    await updateProgress(data.markedImageId, 'Uploading marked image...');
    console.log('Uploading marked image to:', markedGcsPath);
    await uploadFileAsync(markedFilePath, markedGcsPath);

    // Step 4: Get signed URL (valid for 10 years)
    await updateProgress(data.markedImageId, 'Generating URL...');
    var servingUrl = await storageHelper.getSignedUrl(markedGcsPath);
    console.log('Got signed URL:', servingUrl);

    // Step 5: Update Firestore with the marked image data (clears progress)
    await db.collection('markedImages').doc(data.markedImageId).update({
      path: markedGcsPath,
      servingUrl: servingUrl,
      progress: null,
      processedAt: new Date()
    });

    console.log('Marking task completed successfully');
  }
};
