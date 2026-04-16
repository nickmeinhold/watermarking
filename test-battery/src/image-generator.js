/**
 * Synthetic test image generators.
 *
 * Each function returns a PNG Buffer at the specified size, designed to
 * exercise different frequency characteristics of the watermarking algorithm.
 */

import sharp from 'sharp';

const DEFAULT_SIZE = 256;

/**
 * Horizontal gradient from black to white.
 * Smooth, low-frequency content — easiest for DFT watermarking.
 */
export async function generateGradient(size = DEFAULT_SIZE) {
  const channels = 3;
  const data = Buffer.alloc(size * size * channels);

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const val = Math.round((x / (size - 1)) * 255);
      const offset = (y * size + x) * channels;
      data[offset] = val;     // R
      data[offset + 1] = val; // G
      data[offset + 2] = val; // B
    }
  }

  return sharp(data, { raw: { width: size, height: size, channels } })
    .png()
    .toBuffer();
}

/**
 * Alternating black and white blocks.
 * Rich high-frequency content — stresses the frequency domain embedding.
 */
export async function generateCheckerboard(size = DEFAULT_SIZE, blockSize = 16) {
  const channels = 3;
  const data = Buffer.alloc(size * size * channels);

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const isWhite = (Math.floor(x / blockSize) + Math.floor(y / blockSize)) % 2 === 0;
      const val = isWhite ? 255 : 0;
      const offset = (y * size + x) * channels;
      data[offset] = val;
      data[offset + 1] = val;
      data[offset + 2] = val;
    }
  }

  return sharp(data, { raw: { width: size, height: size, channels } })
    .png()
    .toBuffer();
}

/**
 * Random pixel values — uniform noise.
 * Worst case for watermarking: no coherent structure to hide the signal in.
 */
export async function generateNoise(size = DEFAULT_SIZE) {
  const channels = 3;
  const data = Buffer.alloc(size * size * channels);

  for (let i = 0; i < data.length; i++) {
    data[i] = Math.floor(Math.random() * 256);
  }

  return sharp(data, { raw: { width: size, height: size, channels } })
    .png()
    .toBuffer();
}

/**
 * Smooth gradient with additive noise — simulates natural photo-like content.
 * Medium frequency content, closest to real-world images.
 */
export async function generateNaturalLike(size = DEFAULT_SIZE) {
  const channels = 3;
  const data = Buffer.alloc(size * size * channels);

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      // Diagonal gradient as base
      const base = ((x + y) / (2 * (size - 1))) * 200 + 28;
      const offset = (y * size + x) * channels;

      for (let c = 0; c < channels; c++) {
        // Add Gaussian-ish noise (Box-Muller approximation via sum of uniforms)
        const noise = (Math.random() + Math.random() + Math.random() - 1.5) * 30;
        data[offset + c] = Math.max(0, Math.min(255, Math.round(base + noise)));
      }
    }
  }

  return sharp(data, { raw: { width: size, height: size, channels } })
    .png()
    .toBuffer();
}

/** All generators, keyed by name. */
export const IMAGE_GENERATORS = {
  gradient: generateGradient,
  checkerboard: generateCheckerboard,
  noise: generateNoise,
  'natural-like': generateNaturalLike,
};
