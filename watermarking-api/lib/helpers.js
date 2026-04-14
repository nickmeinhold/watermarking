// Utility functions for file cleanup and C++ progress parsing

const fs = require('fs');

/// Safely delete a file if it exists.
function safeUnlink(filePath, jobId = null) {
  if (filePath && fs.existsSync(filePath)) {
    try {
      fs.unlinkSync(filePath);
    } catch (err) {
      const prefix = jobId ? `[${jobId}] ` : '';
      console.error(`${prefix}Error cleaning up file ${filePath}:`, err);
    }
  }
}

/// Clean up uploaded files from a multer request.
function cleanupUploadedFiles(req, jobId = null) {
  // Single file upload (e.g., /watermark endpoint)
  if (req.file && req.file.path) {
    safeUnlink(req.file.path, jobId);
  }
  // Multiple file upload (e.g., /detect endpoint)
  if (req.files) {
    Object.values(req.files).flat().forEach(f => {
      if (f && f.path) {
        safeUnlink(f.path, jobId);
      }
    });
  }
}

/// Parse progress from C++ marking binary stdout.
function parseMarkProgress(line) {
  if (!line.startsWith('PROGRESS:')) {
    return null;
  }

  const parts = line.substring(9).split(':');
  const step = parts[0];

  if (step === 'loading') {
    return { progress: 'Loading image...', percent: 10 };
  } else if (step === 'marking') {
    const current = parseInt(parts[1], 10);
    const total = parseInt(parts[2], 10);
    const percent = Math.round(10 + (current / total) * 70);
    return { progress: `Embedding watermark (${current}/${total})`, percent };
  } else if (step === 'saving') {
    return { progress: 'Compressing image...', percent: 90 };
  }

  return null;
}

/// Parse progress from C++ detection binary stdout.
function parseDetectProgress(line) {
  if (!line.startsWith('PROGRESS:')) {
    return null;
  }

  const msg = line.substring(9).trim();

  if (msg.includes('Extracting watermark')) {
    return { progress: msg, percent: 20 };
  }

  const seqMatch = msg.match(/Analyzing sequence (\d+)/);
  if (seqMatch) {
    const seqNum = parseInt(seqMatch[1], 10);
    const percent = Math.min(90, 30 + seqNum * 4);
    return { progress: msg, percent };
  }

  return { progress: msg, percent: 50 };
}

module.exports = {
  safeUnlink,
  cleanupUploadedFiles,
  parseMarkProgress,
  parseDetectProgress,
};
