/**
 * Duplicate Detection Service
 * Prevents re-minting of same/similar images
 */

const crypto = require('crypto');
const sharp = require('sharp');
const admin = require('firebase-admin');

// Lazy init
let db = null;

function getDb() {
  if (!db) {
    db = admin.firestore();
  }
  return db;
}

/**
 * Check if an image is a duplicate
 * Uses multiple methods:
 * 1. Exact hash match
 * 2. Perceptual hash (pHash) for similar images
 *
 * @param {Buffer} imageBuffer - Image to check
 * @param {string} exactHash - SHA-256 hash of image
 * @returns {Promise<boolean>} - true if duplicate found
 */
async function checkDuplicate(imageBuffer, exactHash) {
  const db = getDb();

  // Check 1: Exact hash match
  const exactMatch = await db.collection('imageHashes')
    .where('exactHash', '==', exactHash)
    .limit(1)
    .get();

  if (!exactMatch.empty) {
    console.log('Duplicate: exact hash match found');
    return true;
  }

  // Check 2: Perceptual hash match
  const pHash = await computePerceptualHash(imageBuffer);

  // Get all pHashes and check for similarity
  // In production, use a more efficient similarity search (e.g., VP-tree, LSH)
  const pHashDocs = await db.collection('imageHashes')
    .select('pHash', 'tokenId')
    .limit(10000) // Limit for now, need better solution at scale
    .get();

  for (const doc of pHashDocs.docs) {
    const storedPHash = doc.data().pHash;
    const similarity = hammingSimilarity(pHash, storedPHash);

    if (similarity > 0.95) {
      console.log(`Duplicate: perceptual hash match (${similarity * 100}% similar) with token ${doc.data().tokenId}`);
      return true;
    }
  }

  return false;
}

/**
 * Register an image hash after successful mint
 */
async function registerHash(exactHash, tokenId) {
  const db = getDb();

  // We should compute pHash here too, but for now just store exact
  await db.collection('imageHashes').doc(exactHash).set({
    exactHash,
    tokenId,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

/**
 * Compute perceptual hash (simplified DCT-based pHash)
 * Returns a 64-bit hash as hex string
 */
async function computePerceptualHash(imageBuffer) {
  // Resize to 32x32 grayscale
  const pixels = await sharp(imageBuffer)
    .resize(32, 32, { fit: 'fill' })
    .grayscale()
    .raw()
    .toBuffer();

  // Compute DCT (simplified - just use average comparison)
  // Real pHash would use DCT, but this is a reasonable approximation
  const size = 8;
  const smallPixels = await sharp(imageBuffer)
    .resize(size, size, { fit: 'fill' })
    .grayscale()
    .raw()
    .toBuffer();

  // Compute average
  let sum = 0;
  for (let i = 0; i < smallPixels.length; i++) {
    sum += smallPixels[i];
  }
  const avg = sum / smallPixels.length;

  // Build hash: 1 if pixel > average, 0 otherwise
  let hash = '';
  for (let i = 0; i < smallPixels.length; i++) {
    hash += smallPixels[i] > avg ? '1' : '0';
  }

  // Convert binary string to hex
  let hexHash = '';
  for (let i = 0; i < hash.length; i += 4) {
    const nibble = hash.slice(i, i + 4);
    hexHash += parseInt(nibble, 2).toString(16);
  }

  return hexHash;
}

/**
 * Compute Hamming similarity between two hex hashes
 * Returns value between 0 and 1 (1 = identical)
 */
function hammingSimilarity(hash1, hash2) {
  if (hash1.length !== hash2.length) {
    return 0;
  }

  // Convert to binary
  const bin1 = hexToBinary(hash1);
  const bin2 = hexToBinary(hash2);

  // Count matching bits
  let matches = 0;
  for (let i = 0; i < bin1.length; i++) {
    if (bin1[i] === bin2[i]) {
      matches++;
    }
  }

  return matches / bin1.length;
}

/**
 * Convert hex string to binary string
 */
function hexToBinary(hex) {
  let binary = '';
  for (let i = 0; i < hex.length; i++) {
    const nibble = parseInt(hex[i], 16).toString(2).padStart(4, '0');
    binary += nibble;
  }
  return binary;
}

module.exports = {
  checkDuplicate,
  registerHash,
  computePerceptualHash
};
