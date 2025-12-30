// storage-helper.js
// Helper module for Google Cloud Storage operations
// Replaces gsutil command-line calls with @google-cloud/storage SDK

const { Storage } = require('@google-cloud/storage');
const fs = require('fs');
const path = require('path');

// Initialize Storage client with credentials from Firebase Admin
// The service account JSON should have storage permissions
const storage = new Storage({
  keyFilename: '/app/keys/firebase-service-account.json'
});

const BUCKET_NAME = 'watermarking-4a428.firebasestorage.app';

/**
 * Downloads a file from Google Cloud Storage
 * @param {string} gcsPath - Path within the GCS bucket (e.g., 'originals/image.png')
 * @param {string} localPath - Local file system path to save to (e.g., '/tmp/123/image.png')
 * @param {function} callback - Callback function(error)
 */
function downloadFile(gcsPath, localPath, callback) {
  console.log(`Downloading from GCS: gs://${BUCKET_NAME}/${gcsPath} -> ${localPath}`);

  // Ensure directory exists
  const dir = path.dirname(localPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const bucket = storage.bucket(BUCKET_NAME);
  const file = bucket.file(gcsPath);

  file.download({ destination: localPath })
    .then(() => {
      console.log(`Successfully downloaded to ${localPath}`);
      callback(null);
    })
    .catch((error) => {
      console.error(`Error downloading file: ${error}`);
      callback(error);
    });
}

/**
 * Downloads a file from Google Cloud Storage with progress updates
 * @param {string} gcsPath - Path within the GCS bucket
 * @param {string} localPath - Local file system path to save to
 * @param {function} onProgress - Callback(percent, bytesDownloaded, totalBytes)
 * @returns {Promise<void>}
 */
function downloadFileWithProgress(gcsPath, localPath, onProgress) {
  return new Promise(async (resolve, reject) => {
    console.log(`Downloading (stream) from GCS: gs://${BUCKET_NAME}/${gcsPath} -> ${localPath}`);

    // Ensure directory exists
    const dir = path.dirname(localPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    const bucket = storage.bucket(BUCKET_NAME);
    const file = bucket.file(gcsPath);

    try {
      // Get file metadata to know total size
      const [metadata] = await file.getMetadata();
      const totalBytes = parseInt(metadata.size, 10);
      let bytesDownloaded = 0;

      const readStream = file.createReadStream();
      const writeStream = fs.createWriteStream(localPath);

      readStream.on('data', (chunk) => {
        bytesDownloaded += chunk.length;
        if (onProgress && totalBytes > 0) {
          const percent = Math.round((bytesDownloaded / totalBytes) * 100);
          onProgress(percent, bytesDownloaded, totalBytes);
        }
      });

      readStream.on('error', (err) => {
        console.error(`Error in read stream: ${err}`);
        reject(err);
      });

      writeStream.on('error', (err) => {
        console.error(`Error in write stream: ${err}`);
        reject(err);
      });

      writeStream.on('finish', () => {
        console.log(`Successfully downloaded to ${localPath}`);
        resolve();
      });

      readStream.pipe(writeStream);
    } catch (err) {
      console.error(`Error starting download: ${err}`);
      reject(err);
    }
  });
}

/**
 * Uploads a file to Google Cloud Storage
 * @param {string} localPath - Local file system path to upload from (e.g., '/tmp/123/image-marked.png')
 * @param {string} gcsPath - Path within the GCS bucket to upload to (e.g., 'marked-images/uid/123/image.png')
 * @param {function} callback - Callback function(error)
 */
function uploadFile(localPath, gcsPath, callback) {
  console.log(`Uploading to GCS: ${localPath} -> gs://${BUCKET_NAME}/${gcsPath}`);

  const bucket = storage.bucket(BUCKET_NAME);

  bucket.upload(localPath, {
    destination: gcsPath,
    metadata: {
      cacheControl: 'public, max-age=31536000',
    }
  })
    .then(() => {
      console.log(`Successfully uploaded to ${gcsPath}`);
      callback(null);
    })
    .catch((error) => {
      console.error(`Error uploading file: ${error}`);
      callback(error);
    });
}

/**
 * Gets the public URL for a file in GCS
 * @param {string} gcsPath - Path within the GCS bucket
 * @returns {string} The public URL for the file
 */
function getPublicUrl(gcsPath) {
  const encodedPath = encodeURIComponent(gcsPath);
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET_NAME}/o/${encodedPath}?alt=media`;
}

/**
 * Gets a signed URL for a file in GCS (valid for 10 years)
 * @param {string} gcsPath - Path within the GCS bucket
 * @returns {Promise<string>} The signed URL for the file
 */
async function getSignedUrl(gcsPath) {
  const bucket = storage.bucket(BUCKET_NAME);
  const file = bucket.file(gcsPath);

  // Generate signed URL valid for 10 years
  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: Date.now() + 10 * 365 * 24 * 60 * 60 * 1000, // 10 years
  });

  return url;
}

/**
 * Deletes a file from GCS
 * @param {string} gcsPath - Path within the GCS bucket
 * @returns {Promise<void>}
 */
async function deleteFile(gcsPath) {
  const bucket = storage.bucket(BUCKET_NAME);
  const file = bucket.file(gcsPath);

  try {
    await file.delete();
    console.log(`Successfully deleted ${gcsPath}`);
  } catch (error) {
    if (error.code === 404) {
      console.log(`File ${gcsPath} not found, ignoring delete error.`);
    } else {
      console.error(`Error deleting file ${gcsPath}:`, error);
      throw error;
    }
  }
}

module.exports = {
  downloadFile,
  uploadFile,
  getPublicUrl,
  getSignedUrl,
  getSignedUrl,
  deleteFile,
  downloadFileWithProgress
};
