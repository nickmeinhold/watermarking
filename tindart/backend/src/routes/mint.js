/**
 * Mint API routes
 * POST /api/mint - Watermark, encrypt, upload, mint NFT
 */

const express = require('express');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

const watermarkService = require('../services/watermark');
const encryptionService = require('../services/encryption');
const ipfsService = require('../services/ipfs');
const blockchainService = require('../services/blockchain');
const firestoreService = require('../services/firestore');
const duplicateService = require('../services/duplicate');

const LICENSE_TYPES = {
  display: 0,
  commercial: 1,
  transfer: 2
};

function createRouter(upload) {
  const router = express.Router();

  /**
   * POST /api/mint
   *
   * Body (multipart/form-data):
   * - image: File (required)
   * - name: string (required)
   * - description: string (optional)
   * - licenseType: "display" | "commercial" | "transfer" (required)
   * - licenseSignature: string (required) - wallet signature of license agreement
   *
   * Returns:
   * - tokenId: number
   * - transactionHash: string
   * - encryptedBlobUri: string
   * - previewUri: string
   * - metadataUri: string
   */
  router.post('/', upload.single('image'), async (req, res, next) => {
    const mintId = uuidv4();

    try {
      console.log(`[${mintId}] Starting mint for wallet: ${req.wallet}`);

      // Validate request
      const { name, description, licenseType, licenseSignature } = req.body;
      const imageBuffer = req.file?.buffer;

      if (!imageBuffer) {
        return res.status(400).json({
          error: 'Image file required',
          code: 'MISSING_IMAGE'
        });
      }

      if (!name || !licenseType || !licenseSignature) {
        return res.status(400).json({
          error: 'Missing required fields: name, licenseType, licenseSignature',
          code: 'MISSING_FIELDS'
        });
      }

      if (!LICENSE_TYPES.hasOwnProperty(licenseType)) {
        return res.status(400).json({
          error: 'Invalid licenseType. Must be: display, commercial, or transfer',
          code: 'INVALID_LICENSE_TYPE'
        });
      }

      // Step 1: Check for duplicates
      console.log(`[${mintId}] Checking for duplicates...`);
      const imageHash = crypto.createHash('sha256').update(imageBuffer).digest('hex');

      const isDuplicate = await duplicateService.checkDuplicate(imageBuffer, imageHash);
      if (isDuplicate) {
        return res.status(409).json({
          error: 'This image or a very similar one has already been minted',
          code: 'DUPLICATE_IMAGE'
        });
      }

      // Step 2: Apply watermark
      console.log(`[${mintId}] Applying watermark...`);
      const watermarkId = `TIND${mintId.slice(0, 8).toUpperCase()}`;
      const watermarkedBuffer = await watermarkService.applyWatermark(
        imageBuffer,
        watermarkId
      );

      // Step 3: Generate preview (visible thumbnail)
      console.log(`[${mintId}] Generating preview...`);
      const previewBuffer = await watermarkService.generatePreview(watermarkedBuffer);

      // Step 4: Encrypt the watermarked original
      console.log(`[${mintId}] Encrypting original...`);
      const { encryptedBuffer, keyId } = await encryptionService.encrypt(
        watermarkedBuffer,
        mintId
      );

      // Step 5: Upload to IPFS
      console.log(`[${mintId}] Uploading to IPFS...`);
      const [encryptedBlobUri, previewUri] = await Promise.all([
        ipfsService.upload(encryptedBuffer, `${mintId}-encrypted`),
        ipfsService.upload(previewBuffer, `${mintId}-preview.jpg`)
      ]);

      // Step 6: Create and upload metadata
      console.log(`[${mintId}] Creating metadata...`);
      const licenseText = generateLicenseText(licenseType, req.wallet, name);
      const licenseHash = crypto.createHash('sha256').update(licenseText).digest('hex');

      const metadata = {
        name,
        description: description || '',
        image: previewUri,
        encrypted_original: encryptedBlobUri,
        attributes: [
          { trait_type: 'License', value: licenseType },
          { trait_type: 'Watermark ID', value: watermarkId },
          { trait_type: 'Creator', value: req.wallet }
        ],
        properties: {
          license_type: licenseType,
          license_hash: licenseHash,
          image_hash: imageHash,
          watermark_id: watermarkId,
          created_at: new Date().toISOString()
        }
      };

      const metadataUri = await ipfsService.uploadJson(metadata, `${mintId}-metadata.json`);

      // Step 7: Mint NFT on-chain
      console.log(`[${mintId}] Minting NFT...`);
      const { tokenId, transactionHash } = await blockchainService.mint(
        req.wallet,
        metadataUri,
        LICENSE_TYPES[licenseType],
        `0x${imageHash}`,
        `0x${licenseHash}`,
        encryptedBlobUri
      );

      // Step 8: Store in Firestore
      console.log(`[${mintId}] Storing in Firestore...`);
      await firestoreService.createToken({
        tokenId,
        mintId,
        wallet: req.wallet,
        name,
        description,
        licenseType,
        imageHash,
        licenseHash,
        watermarkId,
        keyId,
        encryptedBlobUri,
        previewUri,
        metadataUri,
        transactionHash,
        createdAt: new Date()
      });

      // Register hash for duplicate detection
      await duplicateService.registerHash(imageHash, tokenId);

      console.log(`[${mintId}] Mint complete! Token ID: ${tokenId}`);

      res.status(201).json({
        success: true,
        tokenId,
        transactionHash,
        watermarkId,
        encryptedBlobUri,
        previewUri,
        metadataUri,
        imageHash,
        licenseHash
      });

    } catch (error) {
      console.error(`[${mintId}] Mint failed:`, error);
      next(error);
    }
  });

  /**
   * GET /api/mint/price
   * Returns current minting prices
   */
  router.get('/price', (req, res) => {
    res.json({
      display: { usd: 1.00, description: 'Personal display rights' },
      commercial: { usd: 5.00, description: 'Commercial usage rights' },
      transfer: { usd: 10.00, description: 'Full copyright transfer' }
    });
  });

  /**
   * GET /api/mint/license/:type
   * Returns license agreement text for signing
   */
  router.get('/license/:type', (req, res) => {
    const { type } = req.params;

    if (!LICENSE_TYPES.hasOwnProperty(type)) {
      return res.status(400).json({
        error: 'Invalid license type',
        code: 'INVALID_LICENSE_TYPE'
      });
    }

    const licenseText = generateLicenseTemplate(type);
    res.json({ licenseType: type, text: licenseText });
  });

  return router;
}

/**
 * Generate license text for a specific mint
 */
function generateLicenseText(type, creatorWallet, artworkName) {
  const date = new Date().toISOString();

  const templates = {
    display: `
TINDART LICENSE AGREEMENT - DISPLAY

Artwork: ${artworkName}
Creator: ${creatorWallet}
Date: ${date}

This license grants the NFT holder personal, non-commercial display rights only.

The holder MAY:
- Display the artwork for personal enjoyment
- Resell or transfer the NFT

The holder MAY NOT:
- Use the artwork commercially
- Create derivative works
- Sublicense the artwork

Copyright remains with the creator.
    `.trim(),

    commercial: `
TINDART LICENSE AGREEMENT - COMMERCIAL

Artwork: ${artworkName}
Creator: ${creatorWallet}
Date: ${date}

This license grants the NFT holder commercial usage rights.

The holder MAY:
- Display the artwork publicly or privately
- Use the artwork in commercial projects
- Create and sell merchandise featuring the artwork
- Create derivative works
- Resell or transfer the NFT (license transfers with it)

The holder MAY NOT:
- Claim original authorship
- Sublicense independently of the NFT
- Use in illegal or hateful contexts

Copyright remains with the creator. Commercial rights transfer with the NFT.
    `.trim(),

    transfer: `
TINDART LICENSE AGREEMENT - COPYRIGHT TRANSFER

Artwork: ${artworkName}
Creator: ${creatorWallet}
Date: ${date}

This agreement transfers full copyright ownership to the NFT holder.

Upon purchase, the holder receives:
- Full copyright ownership
- All reproduction rights
- All derivative work rights
- All commercial rights
- Right to sublicense
- Right to register copyright in their name

The creator retains:
- Moral rights (where applicable by law)
- Right to be credited as original author

This is a complete and irrevocable transfer of copyright.
    `.trim()
  };

  return templates[type];
}

/**
 * Generate license template (without specific details)
 */
function generateLicenseTemplate(type) {
  const templates = {
    display: `
TINDART LICENSE AGREEMENT - DISPLAY

This license grants personal, non-commercial display rights only.

You MAY:
- Display the artwork for personal enjoyment
- Resell or transfer the NFT

You MAY NOT:
- Use the artwork commercially
- Create derivative works
- Sublicense the artwork

Copyright remains with the creator.
    `.trim(),

    commercial: `
TINDART LICENSE AGREEMENT - COMMERCIAL

This license grants commercial usage rights.

You MAY:
- Display the artwork publicly or privately
- Use the artwork in commercial projects
- Create and sell merchandise
- Create derivative works
- Resell or transfer the NFT (license transfers with it)

You MAY NOT:
- Claim original authorship
- Sublicense independently of the NFT

Copyright remains with the creator. Commercial rights transfer with the NFT.
    `.trim(),

    transfer: `
TINDART LICENSE AGREEMENT - COPYRIGHT TRANSFER

This agreement transfers full copyright ownership to you.

You receive:
- Full copyright ownership
- All reproduction rights
- All derivative work rights
- All commercial rights
- Right to sublicense

The creator retains:
- Moral rights (where applicable by law)
- Right to be credited as original author

This is a complete and irrevocable transfer of copyright.
    `.trim()
  };

  return templates[type];
}

module.exports = createRouter;
