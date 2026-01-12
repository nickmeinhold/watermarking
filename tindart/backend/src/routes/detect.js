/**
 * Detection API routes
 * POST /api/detect - Detect watermark in captured image
 */

const express = require('express');
const crypto = require('crypto');
const { spawn } = require('child_process');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');
const { v4: uuidv4 } = require('uuid');

const encryptionService = require('../services/encryption');
const ipfsService = require('../services/ipfs');
const blockchainService = require('../services/blockchain');
const firestoreService = require('../services/firestore');

const DETECT_BINARY = process.env.DETECT_BINARY || './detect-wm';

function createRouter(upload) {
  const router = express.Router();

  /**
   * POST /api/detect
   *
   * Body (multipart/form-data):
   * - capturedImage: File (required) - Photo of potentially watermarked artwork
   * - tokenId: number (required) - Token ID to check against
   *
   * Returns:
   * - detected: boolean
   * - confidence: number
   * - message: string (decoded watermark message)
   * - owner: string (current NFT owner)
   * - licenseType: string
   */
  router.post('/', upload.single('capturedImage'), async (req, res, next) => {
    const detectId = uuidv4();

    try {
      console.log(`[${detectId}] Starting detection for wallet: ${req.wallet}`);

      const { tokenId } = req.body;
      const capturedBuffer = req.file?.buffer;

      if (!capturedBuffer) {
        return res.status(400).json({
          error: 'Captured image required',
          code: 'MISSING_IMAGE'
        });
      }

      if (!tokenId) {
        return res.status(400).json({
          error: 'Token ID required',
          code: 'MISSING_TOKEN_ID'
        });
      }

      // Step 1: Verify requester owns the NFT (optional, could allow anyone)
      const isOwner = await blockchainService.isOwner(tokenId, req.wallet);
      if (!isOwner) {
        // Allow detection but note they're not the owner
        console.log(`[${detectId}] Requester is not token owner`);
      }

      // Step 2: Get token data
      const token = await firestoreService.getToken(tokenId);
      if (!token) {
        return res.status(404).json({
          error: 'Token not found',
          code: 'TOKEN_NOT_FOUND'
        });
      }

      // Step 3: Fetch encrypted original from IPFS
      console.log(`[${detectId}] Fetching encrypted original from IPFS...`);
      const encryptedBuffer = await ipfsService.fetch(token.encryptedBlobUri);

      // Step 4: Decrypt original
      console.log(`[${detectId}] Decrypting original...`);
      const originalBuffer = await encryptionService.decrypt(encryptedBuffer);

      // Step 5: Run detection
      console.log(`[${detectId}] Running detection...`);
      const result = await runDetection(detectId, originalBuffer, capturedBuffer);

      // Step 6: Get current owner from chain
      const tokenData = await blockchainService.getTokenData(tokenId);

      // Step 7: Log detection
      const capturedHash = crypto.createHash('sha256').update(capturedBuffer).digest('hex');
      await firestoreService.logDetection({
        tokenId,
        requester: req.wallet,
        capturedImageHash: capturedHash,
        result: result.detected,
        confidence: result.confidence
      });

      console.log(`[${detectId}] Detection complete: ${result.detected ? 'FOUND' : 'NOT FOUND'}`);

      res.json({
        detected: result.detected,
        confidence: result.confidence,
        message: result.message,
        owner: tokenData.currentOwner,
        creator: tokenData.creator,
        licenseType: ['display', 'commercial', 'transfer'][tokenData.licenseType],
        statistics: result.statistics
      });

    } catch (error) {
      console.error(`[${detectId}] Detection failed:`, error);
      next(error);
    }
  });

  return router;
}

/**
 * Run the C++ detection binary
 */
async function runDetection(detectId, originalBuffer, capturedBuffer) {
  const tempDir = os.tmpdir();
  const originalPath = path.join(tempDir, `${detectId}-original.png`);
  const capturedPath = path.join(tempDir, `${detectId}-captured.png`);
  const resultPath = path.join(tempDir, `${detectId}.json`);

  try {
    // Write images to temp files
    await fs.writeFile(originalPath, originalBuffer);
    await fs.writeFile(capturedPath, capturedBuffer);

    // Run detection binary
    await new Promise((resolve, reject) => {
      const proc = spawn(DETECT_BINARY, [detectId, originalPath, capturedPath]);

      let stdout = '';
      let stderr = '';

      proc.stdout.on('data', (data) => {
        stdout += data.toString();
        const lines = data.toString().split('\n');
        for (const line of lines) {
          if (line.startsWith('PROGRESS:')) {
            console.log(`[${detectId}] ${line.replace('PROGRESS:', '')}`);
          }
        }
      });

      proc.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      proc.on('close', (code) => {
        if (code === 0) {
          resolve(stdout);
        } else {
          reject(new Error(`Detection binary exited with code ${code}: ${stderr}`));
        }
      });

      proc.on('error', (err) => {
        reject(new Error(`Failed to run detection binary: ${err.message}`));
      });
    });

    // Read results
    const resultJson = await fs.readFile(resultPath, 'utf-8');
    const result = JSON.parse(resultJson);

    return {
      detected: result.detected || false,
      confidence: result.confidence || 0,
      message: result.message || '',
      statistics: result.statistics || null
    };

  } finally {
    // Cleanup
    await cleanup(originalPath, capturedPath, resultPath);
  }
}

async function cleanup(...paths) {
  for (const p of paths) {
    try {
      await fs.unlink(p);
    } catch {
      // Ignore
    }
  }
}

module.exports = createRouter;
