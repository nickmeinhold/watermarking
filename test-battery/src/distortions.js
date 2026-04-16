/**
 * Distortion matrix for watermark robustness testing.
 *
 * Each distortion takes a PNG buffer and returns a PNG buffer.
 * The detect binary auto-resizes dimension mismatches, so distortions
 * that change image size (rotation, resize) are fine.
 */

import sharp from 'sharp';

/**
 * Add Gaussian noise to raw pixel data.
 * Uses Box-Muller transform for proper Gaussian distribution.
 */
function addGaussianNoise(data, sigma) {
  const result = Buffer.from(data);
  for (let i = 0; i < result.length; i++) {
    // Box-Muller transform
    const u1 = Math.random() || 1e-10; // Avoid log(0)
    const u2 = Math.random();
    const noise = sigma * Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
    result[i] = Math.max(0, Math.min(255, Math.round(result[i] + noise)));
  }
  return result;
}

/**
 * Identity — no distortion. Baseline for sanity checking.
 */
const identity = {
  name: 'identity',
  apply: async (buf) => buf,
};

/**
 * JPEG compression at various quality levels.
 * Encodes to JPEG (lossy) then back to PNG for detection.
 */
function jpegDistortion(quality) {
  return {
    name: `jpeg-q${quality}`,
    async apply(buf) {
      const jpegBuf = await sharp(buf).jpeg({ quality }).toBuffer();
      return sharp(jpegBuf).png().toBuffer();
    },
  };
}

/**
 * Gaussian blur at various sigma values.
 * sharp.blur() requires sigma >= 0.3.
 */
function blurDistortion(sigma) {
  return {
    name: `blur-s${sigma}`,
    async apply(buf) {
      return sharp(buf).blur(sigma).png().toBuffer();
    },
  };
}

/**
 * Resize down then back up — destroys high-frequency detail.
 * Scale is the intermediate size as a fraction (e.g., 0.5 = half size).
 */
function resizeDistortion(scale) {
  return {
    name: `resize-${Math.round(scale * 100)}pct`,
    async apply(buf) {
      const meta = await sharp(buf).metadata();
      const w = meta.width;
      const h = meta.height;
      const smallW = Math.round(w * scale);
      const smallH = Math.round(h * scale);

      return sharp(buf)
        .resize(smallW, smallH, { kernel: 'lanczos3' })
        .resize(w, h, { kernel: 'lanczos3' })
        .png()
        .toBuffer();
    },
  };
}

/**
 * Rotation by a given number of degrees.
 * The detect binary auto-resizes mismatched dimensions.
 */
function rotationDistortion(degrees) {
  return {
    name: `rotate-${degrees}deg`,
    async apply(buf) {
      return sharp(buf)
        .rotate(degrees, { background: { r: 128, g: 128, b: 128 } })
        .png()
        .toBuffer();
    },
  };
}

/**
 * Gaussian noise addition at various sigma values (on 0-255 scale).
 */
function noiseDistortion(sigma) {
  return {
    name: `noise-s${sigma}`,
    async apply(buf) {
      const { data, info } = await sharp(buf)
        .removeAlpha()
        .raw()
        .toBuffer({ resolveWithObject: true });

      const noisy = addGaussianNoise(data, sigma);

      return sharp(noisy, {
        raw: { width: info.width, height: info.height, channels: info.channels },
      })
        .png()
        .toBuffer();
    },
  };
}

/**
 * Gamma correction — simulates brightness shifts from printing/scanning.
 *
 * Applies the standard gamma transfer function: out = 255 * (in/255)^gamma.
 * gamma < 1 brightens, gamma > 1 darkens. We operate on raw pixels because
 * sharp.gamma() only accepts values >= 1.0.
 */
function gammaDistortion(gamma) {
  return {
    name: `gamma-${gamma}`,
    async apply(buf) {
      const { data, info } = await sharp(buf)
        .removeAlpha()
        .raw()
        .toBuffer({ resolveWithObject: true });

      // Build lookup table for speed
      const lut = new Uint8Array(256);
      for (let i = 0; i < 256; i++) {
        lut[i] = Math.round(255 * Math.pow(i / 255, gamma));
      }

      const result = Buffer.from(data);
      for (let i = 0; i < result.length; i++) {
        result[i] = lut[result[i]];
      }

      return sharp(result, {
        raw: { width: info.width, height: info.height, channels: info.channels },
      })
        .png()
        .toBuffer();
    },
  };
}

/**
 * Combined: JPEG compression + Gaussian blur.
 * Simulates a realistic multi-step degradation pipeline.
 */
function jpegPlusBlur(quality, sigma) {
  return {
    name: `jpeg-q${quality}+blur-s${sigma}`,
    async apply(buf) {
      const jpegBuf = await sharp(buf).jpeg({ quality }).toBuffer();
      return sharp(jpegBuf).blur(sigma).png().toBuffer();
    },
  };
}

/**
 * Combined: Resize down/up + JPEG compression.
 * Simulates social media upload pipeline.
 */
function resizePlusJpeg(scale, quality) {
  return {
    name: `resize-${Math.round(scale * 100)}pct+jpeg-q${quality}`,
    async apply(buf) {
      const meta = await sharp(buf).metadata();
      const w = meta.width;
      const h = meta.height;
      const smallW = Math.round(w * scale);
      const smallH = Math.round(h * scale);

      const resized = await sharp(buf)
        .resize(smallW, smallH, { kernel: 'lanczos3' })
        .resize(w, h, { kernel: 'lanczos3' })
        .toBuffer();

      const jpegBuf = await sharp(resized).jpeg({ quality }).toBuffer();
      return sharp(jpegBuf).png().toBuffer();
    },
  };
}

/** The full distortion matrix — 19 variants. */
export const DISTORTIONS = [
  // Baseline
  identity,

  // JPEG compression ladder
  jpegDistortion(10),
  jpegDistortion(30),
  jpegDistortion(50),
  jpegDistortion(75),
  jpegDistortion(95),

  // Gaussian blur
  blurDistortion(0.5),
  blurDistortion(1.0),
  blurDistortion(2.0),

  // Resize down then up
  resizeDistortion(0.5),
  resizeDistortion(0.75),

  // Rotation
  rotationDistortion(1),
  rotationDistortion(5),
  rotationDistortion(15),

  // Gaussian noise
  noiseDistortion(5),
  noiseDistortion(15),
  noiseDistortion(30),

  // Gamma correction
  gammaDistortion(0.7),
  gammaDistortion(1.5),

  // Combined attacks
  jpegPlusBlur(50, 1.0),
  resizePlusJpeg(0.75, 50),
];
