// Google Cloud Storage helper functions

const fs = require('fs');
const path = require('path');
const { bucket } = require('./config');

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

module.exports = { gcsDownload, gcsUpload, gcsSignedUrl, gcsDelete };
