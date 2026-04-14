// In-memory job storage for direct-upload watermark results

const fs = require('fs');
const { JOB_TTL_MS } = require('./config');

const jobs = new Map();

// Cleanup expired jobs periodically
setInterval(() => {
  const now = Date.now();
  for (const [jobId, job] of jobs.entries()) {
    if (now - job.createdAt > JOB_TTL_MS) {
      if (job.markedImagePath && fs.existsSync(job.markedImagePath)) {
        try {
          fs.unlinkSync(job.markedImagePath);
          console.log(`Cleaned up expired job file: ${job.markedImagePath}`);
        } catch (err) {
          console.error(`Error cleaning up file ${job.markedImagePath}:`, err);
        }
      }
      jobs.delete(jobId);
      console.log(`Expired job removed: ${jobId}`);
    }
  }
}, 60 * 1000);

module.exports = { jobs };
