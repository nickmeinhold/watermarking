/**
 * Watermark Robustness Test Battery
 *
 * Exercises the full mark → distort → detect pipeline across a matrix of
 * image types, watermark parameters, and distortion attacks.
 *
 * Run modes:
 *   npm test              # fast mode (2 images, 1 message, 2 strengths)
 *   npm run test:full     # full mode (4 images, 2 messages, 4 strengths)
 *
 * Requires the watermarking API to be running (see scripts/start-docker.sh).
 */

import { describe, test, beforeAll, afterAll, expect } from 'vitest';
import { watermarkImage, detectWatermark, checkHealth } from '../src/api-client.js';
import { getTestMatrix } from '../src/config.js';
import { recordResult, generateReport, clearResults } from '../src/report.js';

const { combos, distortions, config } = getTestMatrix();

// Cache: (imageName-message-strength) → { originalBuffer, markedBuffer }
const markCache = new Map();

describe('Watermark Robustness Battery', () => {
  beforeAll(async () => {
    clearResults();

    // Verify API is reachable before running the full battery
    const healthy = await checkHealth();
    if (!healthy) {
      throw new Error(
        `API not reachable at ${config.apiBaseUrl}. ` +
          'Run scripts/start-docker.sh first, or set TEST_API_URL.',
      );
    }
    console.log(`API healthy at ${config.apiBaseUrl}`);
    console.log(
      `Test matrix: ${combos.length} combos × ${distortions.length} distortions = ${combos.length * distortions.length} tests`,
    );
  });

  afterAll(() => {
    generateReport(config);
  });

  for (const { imageName, generator, message, strength } of combos) {
    const comboKey = `${imageName}-${message}-s${strength}`;

    describe(comboKey, () => {
      /** Generate and watermark the image once per combo. */
      beforeAll(async () => {
        if (markCache.has(comboKey)) return;

        console.log(`  Generating ${imageName} (${config.imageSize}x${config.imageSize})...`);
        const originalBuffer = await generator(config.imageSize);

        console.log(`  Watermarking: message="${message}", strength=${strength}...`);
        const markedBuffer = await watermarkImage(
          originalBuffer,
          `${imageName}.png`,
          message,
          strength,
        );

        markCache.set(comboKey, { originalBuffer, markedBuffer });
        console.log(`  Marked image ready (${markedBuffer.length} bytes)`);
      });

      for (const distortion of distortions) {
        test(`survives ${distortion.name}`, async () => {
          const { originalBuffer, markedBuffer } = markCache.get(comboKey);

          // Apply distortion to the watermarked image
          const distortedBuffer = await distortion.apply(markedBuffer);

          // Attempt detection
          let result;
          try {
            result = await detectWatermark(originalBuffer, distortedBuffer);
          } catch (err) {
            recordResult({
              imageName,
              message,
              strength,
              distortionName: distortion.name,
              error: err.message,
            });
            throw err;
          }

          // Get baseline confidence from identity test if available
          const baselineKey = `${comboKey}-identity`;
          const baselineResult = markCache.get(baselineKey);

          // Record the result for the report
          recordResult({
            imageName,
            message,
            strength,
            distortionName: distortion.name,
            detected: result.detected,
            detectedMessage: result.message,
            confidence: result.confidence,
            baselineConfidence: baselineResult?.confidence || null,
          });

          // Cache identity confidence for other tests in this combo
          if (distortion.name === 'identity') {
            markCache.set(baselineKey, { confidence: result.confidence });
          }

          // Assertions
          expect(result.detected, `Watermark not detected after ${distortion.name}`).toBe(true);
          expect(
            result.message,
            `Wrong message after ${distortion.name}: got "${result.message}", expected "${message}"`,
          ).toBe(message);
          expect(
            result.confidence,
            `Confidence ${result.confidence} below threshold ${config.threshold} after ${distortion.name}`,
          ).toBeGreaterThan(config.threshold);
        });
      }
    });
  }
});
