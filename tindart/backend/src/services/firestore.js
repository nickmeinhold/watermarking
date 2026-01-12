/**
 * Firestore Service
 * Token metadata and key storage
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (lazy)
let db = null;

function getDb() {
  if (!db) {
    if (!admin.apps.length) {
      const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT
        ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
        : require('../../keys/firebase-service-account.json');

      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: process.env.FIREBASE_PROJECT_ID || 'tindart'
      });
    }
    db = admin.firestore();
  }
  return db;
}

/**
 * Create a new token record
 */
async function createToken(data) {
  const db = getDb();

  const tokenDoc = {
    tokenId: data.tokenId,
    mintId: data.mintId,
    wallet: data.wallet,
    name: data.name,
    description: data.description || '',
    licenseType: data.licenseType,
    imageHash: data.imageHash,
    licenseHash: data.licenseHash,
    watermarkId: data.watermarkId,
    keyId: data.keyId,
    encryptedBlobUri: data.encryptedBlobUri,
    previewUri: data.previewUri,
    metadataUri: data.metadataUri,
    transactionHash: data.transactionHash,
    createdAt: admin.firestore.Timestamp.fromDate(data.createdAt)
  };

  await db.collection('tokens').doc(String(data.tokenId)).set(tokenDoc);

  return tokenDoc;
}

/**
 * Get token by ID
 */
async function getToken(tokenId) {
  const db = getDb();
  const doc = await db.collection('tokens').doc(String(tokenId)).get();

  if (!doc.exists) {
    return null;
  }

  return doc.data();
}

/**
 * Get tokens by wallet
 */
async function getTokensByWallet(wallet, limit = 50) {
  const db = getDb();
  const snapshot = await db.collection('tokens')
    .where('wallet', '==', wallet.toLowerCase())
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  return snapshot.docs.map(doc => doc.data());
}

/**
 * Store encrypted key reference
 */
async function storeKey(tokenId, keyData) {
  const db = getDb();

  await db.collection('keys').doc(String(tokenId)).set({
    tokenId,
    keyId: keyData.keyId,
    imageHash: keyData.imageHash,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

/**
 * Get key reference
 */
async function getKey(tokenId) {
  const db = getDb();
  const doc = await db.collection('keys').doc(String(tokenId)).get();

  if (!doc.exists) {
    return null;
  }

  return doc.data();
}

/**
 * Log a detection request
 */
async function logDetection(data) {
  const db = getDb();

  await db.collection('detections').add({
    tokenId: data.tokenId,
    requester: data.requester,
    capturedImageHash: data.capturedImageHash,
    result: data.result,
    confidence: data.confidence,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  });
}

/**
 * Get detection history for a token
 */
async function getDetectionHistory(tokenId, limit = 20) {
  const db = getDb();
  const snapshot = await db.collection('detections')
    .where('tokenId', '==', tokenId)
    .orderBy('timestamp', 'desc')
    .limit(limit)
    .get();

  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

module.exports = {
  createToken,
  getToken,
  getTokensByWallet,
  storeKey,
  getKey,
  logDetection,
  getDetectionHistory
};
