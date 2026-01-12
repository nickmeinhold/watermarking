/**
 * Tindart Backend API
 * Handles: watermarking, encryption, IPFS upload, NFT minting
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const multer = require('multer');

const authMiddleware = require('./middleware/auth');
const mintRouter = require('./routes/mint');
const detectRouter = require('./routes/detect');
const verifyRouter = require('./routes/verify');

const app = express();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB max
});

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'tindart-api',
    version: '1.0.0'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Public routes
app.use('/api/verify', verifyRouter);

// Authenticated routes
app.use('/api/mint', authMiddleware, mintRouter(upload));
app.use('/api/detect', authMiddleware, detectRouter(upload));

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    code: err.code || 'INTERNAL_ERROR'
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Tindart API running on port ${PORT}`);
});

module.exports = app;
