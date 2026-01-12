/**
 * Pure functions for parsing progress output from C++ binaries
 */

/**
 * Parse a single line of marking progress output
 * @param {string} line - A line from stdout
 * @param {object} context - Context with markingStartTime and currentMarkingStatus
 * @returns {{progressText: string|null, context: object}} Updated progress and context
 */
function parseMarkingProgressLine(line, context = {}) {
  const result = {
    progressText: null,
    context: { ...context }
  };

  if (!line || !line.startsWith('PROGRESS:')) {
    return result;
  }

  const parts = line.substring(9).split(':');
  const step = parts[0];

  if (step === 'loading') {
    result.progressText = 'Loading image...';
  } else if (step === 'marking') {
    const current = parseInt(parts[1], 10);
    const total = parseInt(parts[2], 10);

    if (isNaN(current) || isNaN(total)) {
      return result;
    }

    if (current === 1) {
      result.context.markingStartTime = Date.now();
    }

    let etaText = '';
    if (current > 1 && result.context.markingStartTime > 0) {
      etaText = calculateEtaText(
        current,
        total,
        Date.now() - result.context.markingStartTime
      );
    }

    result.context.currentMarkingStatus = `Embedding watermark (${current}/${total})${etaText}`;
    result.progressText = result.context.currentMarkingStatus;
  } else if (step === 'saving') {
    result.progressText = 'Compressing image...';
  } else if (step === 'dft') {
    result.progressText = (result.context.currentMarkingStatus || 'Processing') + ' - DFT...';
  } else if (step === 'idft') {
    result.progressText = (result.context.currentMarkingStatus || 'Processing') + ' - IDFT...';
  }

  return result;
}

/**
 * Calculate ETA text from progress data
 * @param {number} current - Current step (1-indexed)
 * @param {number} total - Total steps
 * @param {number} elapsedMs - Elapsed time in milliseconds since step 1
 * @returns {string} ETA text like " - 5m 30s remaining" or empty string
 */
function calculateEtaText(current, total, elapsedMs) {
  if (current <= 1 || elapsedMs <= 0 || total <= 0) {
    return '';
  }

  const stepsDone = current - 1;
  const avgPerStep = elapsedMs / stepsDone;
  const stepsRemaining = total - current;

  if (stepsRemaining <= 0) {
    return '';
  }

  const etaMs = avgPerStep * stepsRemaining;
  const totalSeconds = Math.round(etaMs / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;

  if (minutes > 0) {
    return ` - ${minutes}m ${seconds}s remaining`;
  } else {
    return ` - ${seconds}s remaining`;
  }
}

/**
 * Parse a detection progress line
 * @param {string} line - A line from stdout
 * @returns {string|null} Progress message or null
 */
function parseDetectionProgressLine(line) {
  if (!line || !line.startsWith('PROGRESS:')) {
    return null;
  }
  return line.replace('PROGRESS:', '').trim();
}

/**
 * Parse size mismatch error from detection output
 * @param {string} stdout - Full stdout from detect-wm
 * @returns {string} Error message with size info if available
 */
function parseSizeMismatchError(stdout) {
  let errorMessage = 'Different sizes for marked and original images';

  if (!stdout) {
    return errorMessage;
  }

  const sizeMatch = stdout.match(/Original: (\d+x\d+), Marked: (\d+x\d+)/);
  if (sizeMatch) {
    errorMessage += ` (${sizeMatch[1]} vs ${sizeMatch[2]})`;
  }

  return errorMessage;
}

module.exports = {
  parseMarkingProgressLine,
  calculateEtaText,
  parseDetectionProgressLine,
  parseSizeMismatchError
};
