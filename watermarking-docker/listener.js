// listener.js
// ===========
// Main entry point for the watermarking backend service

var http = require('http');
var taskQueue = require('./task-queue');

console.log('Starting watermarking backend service...');

// Setup the Firestore task queue listener (async for stale task recovery)
(async () => {
  await taskQueue.setup();
  console.log('Task queue listener is active.');
})();

// Cloud Run requires an HTTP server to respond to health checks
const PORT = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      queues: 'running',
      timestamp: new Date().toISOString()
    }));
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(PORT, () => {
  console.log(`HTTP server listening on port ${PORT} for Cloud Run health checks`);
  console.log('Firestore task queue is active and processing tasks...');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down...');
  taskQueue.shutdown();
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
