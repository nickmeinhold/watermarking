// Firebase, GCS, and application configuration

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

const PORT = process.env.PORT || 8080;
const API_KEY = process.env.API_KEY;
const DEFAULT_STRENGTH = parseInt(process.env.DEFAULT_STRENGTH, 10) || 10;
const JOB_TTL_MS = 5 * 60 * 1000; // 5 minutes
const PROCESS_TIMEOUT_MS = 4 * 60 * 1000; // 4 minutes (Cloud Run has 5-min timeout)

// Validate API_KEY is set
if (!API_KEY) {
  console.error('ERROR: API_KEY environment variable is required');
  process.exit(1);
}

module.exports = {
  admin,
  db,
  bucket,
  PORT,
  API_KEY,
  DEFAULT_STRENGTH,
  JOB_TTL_MS,
  PROCESS_TIMEOUT_MS,
};
