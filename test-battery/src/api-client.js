/**
 * HTTP client for the watermarking REST API.
 *
 * Handles SSE (Server-Sent Events) stream parsing for the /watermark and
 * /detect endpoints, which stream progress updates before the final result.
 */

import { getConfig } from './config.js';

/**
 * Parse an SSE response stream, collecting all events until completion.
 *
 * The API sends lines like:
 *   data: {"progress":"Loading image...","percent":10}\n\n
 *   data: {"complete":true,"downloadUrl":"/download/abc"}\n\n
 *
 * Returns the final event (the one with `complete: true` or `error`).
 */
async function consumeSSEStream(response) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let lastEvent = null;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });

    // SSE events are separated by double newlines
    const parts = buffer.split('\n\n');
    // Keep the last (possibly incomplete) part in the buffer
    buffer = parts.pop() || '';

    for (const part of parts) {
      const trimmed = part.trim();
      if (!trimmed) continue;

      // Extract the JSON from "data: {...}" lines
      for (const line of trimmed.split('\n')) {
        if (line.startsWith('data: ')) {
          try {
            lastEvent = JSON.parse(line.slice(6));
          } catch {
            // Non-JSON data line, skip
          }
        }
      }
    }
  }

  // Process any remaining buffer content
  if (buffer.trim()) {
    for (const line of buffer.trim().split('\n')) {
      if (line.startsWith('data: ')) {
        try {
          lastEvent = JSON.parse(line.slice(6));
        } catch {
          // ignore
        }
      }
    }
  }

  return lastEvent;
}

/**
 * Watermark an image via the REST API.
 *
 * @param {Buffer} imageBuffer - PNG image data
 * @param {string} filename - Original filename (used by the binary)
 * @param {string} message - Message to embed
 * @param {number} strength - Watermark strength (1-100)
 * @returns {Promise<Buffer>} The watermarked PNG image
 */
export async function watermarkImage(imageBuffer, filename, message, strength) {
  const { apiBaseUrl, apiKey } = getConfig();

  // POST the image for watermarking
  const formData = new FormData();
  formData.append('image', new Blob([imageBuffer], { type: 'image/png' }), filename);
  formData.append('message', message);
  formData.append('strength', String(strength));

  const response = await fetch(`${apiBaseUrl}/watermark`, {
    method: 'POST',
    headers: { 'X-API-Key': apiKey },
    body: formData,
  });

  if (!response.ok && response.headers.get('content-type')?.includes('application/json')) {
    const err = await response.json();
    throw new Error(`Watermark request failed: ${err.error}`);
  }

  const result = await consumeSSEStream(response);

  if (!result) {
    throw new Error('No response received from watermark endpoint');
  }

  if (result.error) {
    throw new Error(`Watermarking failed: ${result.error}`);
  }

  if (!result.complete || !result.downloadUrl) {
    throw new Error(`Unexpected watermark result: ${JSON.stringify(result)}`);
  }

  // Download the watermarked image
  const downloadResponse = await fetch(`${apiBaseUrl}${result.downloadUrl}`, {
    headers: { 'X-API-Key': apiKey },
  });

  if (!downloadResponse.ok) {
    throw new Error(`Download failed: ${downloadResponse.status}`);
  }

  const arrayBuffer = await downloadResponse.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

/**
 * Detect a watermark in an image via the REST API.
 *
 * @param {Buffer} originalBuffer - Original (unwatermarked) PNG image
 * @param {Buffer} watermarkedBuffer - Watermarked/distorted PNG image to test
 * @returns {Promise<Object>} Detection result with detected, message, confidence, statistics
 */
export async function detectWatermark(originalBuffer, watermarkedBuffer) {
  const { apiBaseUrl, apiKey } = getConfig();

  const formData = new FormData();
  formData.append(
    'original',
    new Blob([originalBuffer], { type: 'image/png' }),
    'original.png',
  );
  formData.append(
    'watermarked',
    new Blob([watermarkedBuffer], { type: 'image/png' }),
    'watermarked.png',
  );

  const response = await fetch(`${apiBaseUrl}/detect`, {
    method: 'POST',
    headers: { 'X-API-Key': apiKey },
    body: formData,
  });

  if (!response.ok && response.headers.get('content-type')?.includes('application/json')) {
    const err = await response.json();
    throw new Error(`Detect request failed: ${err.error}`);
  }

  const result = await consumeSSEStream(response);

  if (!result) {
    throw new Error('No response received from detect endpoint');
  }

  if (result.error) {
    throw new Error(`Detection failed: ${result.error}`);
  }

  if (!result.complete) {
    throw new Error(`Unexpected detect result: ${JSON.stringify(result)}`);
  }

  return {
    detected: result.detected || false,
    message: result.message || null,
    confidence: result.confidence || 0,
    statistics: result.statistics || null,
  };
}

/**
 * Check if the API is reachable.
 * @returns {Promise<boolean>}
 */
export async function checkHealth() {
  const { apiBaseUrl } = getConfig();
  try {
    const res = await fetch(`${apiBaseUrl}/health`);
    const data = await res.json();
    return data.status === 'ok';
  } catch {
    return false;
  }
}
