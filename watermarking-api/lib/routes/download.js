// Download endpoint: GET /download/:jobId

const express = require('express');
const fs = require('fs');

const { authenticateApiKey } = require('../auth');
const { jobs } = require('../jobs');

const router = express.Router();

/// Download a watermarked image from an in-memory job.
router.get('/:jobId', authenticateApiKey, (req, res) => {
  const jobId = req.params.jobId;
  const job = jobs.get(jobId);

  if (!job) {
    return res.status(404).json({ error: 'Job not found or expired' });
  }

  if (!fs.existsSync(job.markedImagePath)) {
    jobs.delete(jobId);
    return res.status(404).json({ error: 'File not found' });
  }

  res.setHeader('Content-Type', 'image/png');
  res.setHeader('Content-Disposition', `attachment; filename="watermarked-${jobId}.png"`);

  const fileStream = fs.createReadStream(job.markedImagePath);
  fileStream.pipe(res);

  fileStream.on('error', (err) => {
    console.error(`Error streaming file for job ${jobId}:`, err);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Error reading file' });
    }
  });
});

module.exports = router;
