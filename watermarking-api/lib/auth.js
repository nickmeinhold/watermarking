// Authentication middleware for API key and Firebase token verification

const crypto = require('crypto');
const { admin, API_KEY } = require('./config');

/// Timing-safe string comparison to prevent timing attacks.
function timingSafeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') {
    return false;
  }
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) {
    // Compare against itself to maintain constant time even when lengths differ
    crypto.timingSafeEqual(bufA, bufA);
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

/// API key authentication middleware (for external API consumers).
function authenticateApiKey(req, res, next) {
  const apiKey = req.headers['x-api-key'];

  if (!apiKey) {
    return res.status(401).json({ error: 'Missing X-API-Key header' });
  }

  if (!timingSafeEqual(apiKey, API_KEY)) {
    return res.status(401).json({ error: 'Invalid API key' });
  }

  next();
}

/// Firebase Auth ID token verification middleware (for web/mobile clients).
async function authenticateFirebaseToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const idToken = authHeader.substring(7);
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    req.uid = decoded.uid;
    next();
  } catch (err) {
    console.error('Firebase token verification failed:', err.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { authenticateApiKey, authenticateFirebaseToken };
