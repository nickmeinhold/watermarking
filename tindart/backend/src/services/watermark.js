/**
 * Watermark Service
 * Interfaces with C++ watermarking binaries
 */

const { spawn } = require('child_process');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');
const sharp = require('sharp');
const { v4: uuidv4 } = require('uuid');

const WATERMARK_BINARY = process.env.WATERMARK_BINARY || './mark-image';
const WATERMARK_STRENGTH = process.env.WATERMARK_STRENGTH || '1.0';

/**
 * Apply invisible watermark to image
 * @param {Buffer} imageBuffer - Original image
 * @param {string} message - Message to embed (e.g., "TIND12345678")
 * @returns {Promise<Buffer>} - Watermarked image
 */
async function applyWatermark(imageBuffer, message) {
  const tempId = uuidv4();
  const tempDir = os.tmpdir();
  const inputPath = path.join(tempDir, `${tempId}-input.png`);
  const outputPath = path.join(tempDir, `${tempId}-input-marked.png`);

  try {
    // Convert to PNG (required by watermark binary)
    const pngBuffer = await sharp(imageBuffer)
      .png()
      .toBuffer();

    // Write to temp file
    await fs.writeFile(inputPath, pngBuffer);

    // Run watermark binary
    await runWatermarkBinary(inputPath, message);

    // Read result
    const watermarkedBuffer = await fs.readFile(outputPath);

    return watermarkedBuffer;

  } finally {
    // Cleanup temp files
    await cleanup(inputPath, outputPath);
  }
}

/**
 * Run the C++ watermark binary
 */
function runWatermarkBinary(filePath, message) {
  return new Promise((resolve, reject) => {
    const args = [
      filePath,
      path.basename(filePath),
      message,
      WATERMARK_STRENGTH
    ];

    console.log(`Running: ${WATERMARK_BINARY} ${args.join(' ')}`);

    const proc = spawn(WATERMARK_BINARY, args);

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
      // Log progress updates
      const lines = data.toString().split('\n');
      for (const line of lines) {
        if (line.startsWith('PROGRESS:')) {
          console.log(`Watermark: ${line.replace('PROGRESS:', '')}`);
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
        reject(new Error(`Watermark binary exited with code ${code}: ${stderr}`));
      }
    });

    proc.on('error', (err) => {
      reject(new Error(`Failed to run watermark binary: ${err.message}`));
    });
  });
}

/**
 * Generate a preview/thumbnail image
 * @param {Buffer} imageBuffer - Source image
 * @returns {Promise<Buffer>} - JPEG preview
 */
async function generatePreview(imageBuffer) {
  return sharp(imageBuffer)
    .resize(800, 800, {
      fit: 'inside',
      withoutEnlargement: true
    })
    .jpeg({ quality: 85 })
    .toBuffer();
}

/**
 * Cleanup temp files
 */
async function cleanup(...paths) {
  for (const p of paths) {
    try {
      await fs.unlink(p);
    } catch {
      // Ignore cleanup errors
    }
  }
}

module.exports = {
  applyWatermark,
  generatePreview
};
