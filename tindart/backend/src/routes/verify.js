/**
 * Verify API routes (public, no auth required)
 * GET /api/verify/:tokenId - Get public verification info
 */

const express = require('express');
const router = express.Router();

const blockchainService = require('../services/blockchain');
const firestoreService = require('../services/firestore');
const ipfsService = require('../services/ipfs');

/**
 * GET /api/verify/:tokenId
 * Public verification page data
 *
 * Returns:
 * - token info
 * - current owner
 * - creator
 * - license type
 * - provenance (transfer history)
 */
router.get('/:tokenId', async (req, res, next) => {
  try {
    const { tokenId } = req.params;

    // Get on-chain data
    let tokenData;
    try {
      tokenData = await blockchainService.getTokenData(tokenId);
    } catch (error) {
      return res.status(404).json({
        error: 'Token not found',
        code: 'TOKEN_NOT_FOUND'
      });
    }

    // Get off-chain metadata
    const firestoreData = await firestoreService.getToken(tokenId);

    // Get preview URL
    const previewUrl = firestoreData?.previewUri
      ? ipfsService.getGatewayUrl(firestoreData.previewUri)
      : null;

    // License type names
    const licenseTypes = ['Display', 'Commercial', 'Full Transfer'];

    res.json({
      tokenId: Number(tokenId),
      name: firestoreData?.name || `Tindart #${tokenId}`,
      description: firestoreData?.description || '',
      previewUrl,
      creator: tokenData.creator,
      currentOwner: tokenData.currentOwner,
      licenseType: licenseTypes[tokenData.licenseType] || 'Unknown',
      mintedAt: tokenData.mintedAt.toISOString(),
      watermarkId: firestoreData?.watermarkId || null,
      verified: true,
      contractAddress: process.env.TINDART_CONTRACT_ADDRESS,
      chain: 'Polygon',
      explorerUrl: `https://polygonscan.com/token/${process.env.TINDART_CONTRACT_ADDRESS}?a=${tokenId}`
    });

  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/verify/:tokenId/history
 * Get detection history for a token
 */
router.get('/:tokenId/history', async (req, res, next) => {
  try {
    const { tokenId } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);

    const history = await firestoreService.getDetectionHistory(tokenId, limit);

    res.json({
      tokenId: Number(tokenId),
      detections: history.map(d => ({
        id: d.id,
        detected: d.result,
        confidence: d.confidence,
        timestamp: d.timestamp?.toDate?.()?.toISOString() || null
      }))
    });

  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/verify/check/:imageHash
 * Check if an image hash is already registered
 */
router.get('/check/:imageHash', async (req, res, next) => {
  try {
    const { imageHash } = req.params;

    // Add 0x prefix if not present
    const hash = imageHash.startsWith('0x') ? imageHash : `0x${imageHash}`;

    const isRegistered = await blockchainService.isImageRegistered(hash);

    res.json({
      imageHash: hash,
      registered: isRegistered
    });

  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/verify/stats
 * Get platform statistics
 */
router.get('/stats', async (req, res, next) => {
  try {
    const totalSupply = await blockchainService.totalSupply();

    res.json({
      totalTokens: totalSupply,
      chain: 'Polygon',
      contractAddress: process.env.TINDART_CONTRACT_ADDRESS
    });

  } catch (error) {
    next(error);
  }
});

module.exports = router;
