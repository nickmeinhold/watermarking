/**
 * Test battery configuration.
 *
 * Controls the test matrix size, API connection, and detection threshold.
 * Override via environment variables for different test modes.
 */

import { IMAGE_GENERATORS } from './image-generator.js';
import { DISTORTIONS } from './distortions.js';

const DETECTION_THRESHOLD = 6.0;
const IMAGE_SIZE = 256;

/** Fast mode: minimal matrix for quick feedback. */
const FAST_CONFIG = {
  imageNames: ['gradient', 'natural-like'],
  messages: ['AB'],
  strengths: [10, 25],
};

/** Full mode: comprehensive matrix for thorough evaluation. */
const FULL_CONFIG = {
  imageNames: ['gradient', 'checkerboard', 'noise', 'natural-like'],
  messages: ['AB', 'Test'],
  strengths: [5, 10, 25, 50],
};

/**
 * Get the active test configuration.
 * Reads from environment variables, with sensible defaults for local Docker testing.
 */
export function getConfig() {
  const mode = process.env.TEST_MODE || 'fast';
  const modeConfig = mode === 'full' ? FULL_CONFIG : FAST_CONFIG;

  return {
    apiBaseUrl: process.env.TEST_API_URL || 'http://localhost:8080',
    apiKey: process.env.TEST_API_KEY || 'test-battery-key',
    imageSize: IMAGE_SIZE,
    threshold: DETECTION_THRESHOLD,
    ...modeConfig,
  };
}

/**
 * Get the test matrix — all (image, message, strength) combinations.
 */
export function getTestMatrix() {
  const config = getConfig();
  const combos = [];

  for (const imageName of config.imageNames) {
    const generator = IMAGE_GENERATORS[imageName];
    if (!generator) throw new Error(`Unknown image type: ${imageName}`);

    for (const message of config.messages) {
      for (const strength of config.strengths) {
        combos.push({ imageName, generator, message, strength });
      }
    }
  }

  return { combos, distortions: DISTORTIONS, config };
}

export { DISTORTIONS, IMAGE_GENERATORS };
