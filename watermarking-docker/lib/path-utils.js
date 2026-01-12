/**
 * Pure functions for path manipulation
 */

/**
 * Strip the file extension from a filename
 * @param {string} filename - The filename (may include extension)
 * @returns {string} Filename without extension
 */
function stripExtension(filename) {
  if (!filename) {
    return "";
  }
  // Don't strip extension from hidden files like .gitignore
  const lastDotIndex = filename.lastIndexOf(".");
  if (lastDotIndex <= 0) {
    return filename;
  }
  return filename.substring(0, lastDotIndex);
}

/**
 * Ensure a filename has .png extension (used for marked images)
 * @param {string} filename - The filename
 * @returns {string} Filename with .png extension
 */
function ensurePngExtension(filename) {
  if (!filename) {
    return ".png";
  }

  const lower = filename.toLowerCase();
  if (lower.endsWith(".png")) {
    return filename;
  }

  return stripExtension(filename) + ".png";
}

/**
 * Build the GCS storage path for a marked image
 * @param {string} userId - User ID
 * @param {string} timestamp - Timestamp string
 * @param {string} originalName - Original filename
 * @returns {string} Full GCS path like "marked-images/userId/timestamp/name.png"
 */
function buildMarkedImagePath(userId, timestamp, originalName) {
  const baseName = stripExtension(originalName);
  return `marked-images/${userId}/${timestamp}/${baseName}.png`;
}

/**
 * Build the GCS storage path for a detecting image
 * @param {string} userId - User ID
 * @param {string} itemId - Detection item ID
 * @returns {string} Full GCS path
 */
function buildDetectingImagePath(userId, itemId) {
  return `detecting-images/${userId}/${itemId}`;
}

/**
 * Build a local temp path for processing
 * @param {string} taskId - Task ID
 * @param {string} filename - Optional filename
 * @returns {string} Local path like "/tmp/taskId/filename"
 */
function buildTempPath(taskId, filename) {
  if (filename) {
    return `/tmp/${taskId}/${filename}`;
  }
  return `/tmp/${taskId}`;
}

module.exports = {
  stripExtension,
  ensurePngExtension,
  buildMarkedImagePath,
  buildDetectingImagePath,
  buildTempPath,
};
