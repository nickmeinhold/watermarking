// server.js
// Watermarking REST API with SSE progress streaming

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const rateLimit = require('express-rate-limit');

const { PORT } = require('./lib/config');
const watermarkRoutes = require('./lib/routes/watermark');
const detectRoutes = require('./lib/routes/detect');
const deleteRoutes = require('./lib/routes/delete');
const downloadRoutes = require('./lib/routes/download');
const { cleanupUploadedFiles } = require('./lib/helpers');

// Initialize jobs cleanup (side effect on require)
require('./lib/jobs');

const app = express();

// CORS configuration
const corsOptions = {
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'DELETE'],
  allowedHeaders: ['Content-Type', 'X-API-Key', 'Authorization'],
  exposedHeaders: ['Content-Disposition'],
};
app.use(cors(corsOptions));

// Parse JSON bodies for GCS endpoints
app.use(express.json());

// Rate limiting
// For API-key endpoints, rate limits per key. For Firebase-authed (GCS) endpoints,
// the API key header is absent so this falls back to req.ip. This means users
// behind the same IP share a limit. Acceptable trade-off: decoding the JWT before
// auth middleware would add latency and complexity. Revisit if per-user limiting
// becomes important.
const watermarkLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 10,
  keyGenerator: (req) => req.headers['x-api-key'] || req.ip,
  handler: (req, res) => {
    res.status(429).json({ error: 'Too many requests. Please try again later.' });
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const detectLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 10,
  keyGenerator: (req) => req.headers['x-api-key'] || req.ip,
  handler: (req, res) => {
    res.status(429).json({ error: 'Too many requests. Please try again later.' });
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Configure multer for file uploads
const upload = multer({
  dest: '/tmp/uploads/',
  limits: { fileSize: 50 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['image/png', 'image/jpeg'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only PNG and JPG images are allowed.'));
    }
  }
});

const uploadDetect = multer({
  dest: '/tmp/uploads/',
  limits: { fileSize: 50 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['image/png', 'image/jpeg'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only PNG and JPG images are allowed.'));
    }
  }
});

// Health check (no auth required)
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Routes — multer middleware applied per-route inside route files (not here)
// because GCS endpoints use JSON bodies, not multipart uploads.
app.use('/watermark', watermarkLimiter, watermarkRoutes(upload));
app.use('/detect', detectLimiter, detectRoutes(uploadDetect));
// Delete routes mount at root — paths include /original/:id, /marked/:id, /detection/:id
app.use('/', deleteRoutes);
app.use('/download', downloadRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  cleanupUploadedFiles(req);

  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 50MB.' });
    }
    return res.status(400).json({ error: err.message });
  }

  res.status(500).json({ error: err.message || 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Watermarking API server running on port ${PORT}`);
});
