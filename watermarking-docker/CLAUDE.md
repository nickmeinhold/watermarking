# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Deploy Commands

```bash
# Build for Cloud Run (AMD64 required)
docker buildx build --platform linux/amd64 -f Dockerfile.cloudrun \
  -t gcr.io/watermarking-4a428/watermarking-cloudrun:latest --push .

# Deploy to Cloud Run
gcloud run deploy watermarking-backend \
  --image gcr.io/watermarking-4a428/watermarking-cloudrun:latest \
  --region us-central1 \
  --project watermarking-4a428

# Check logs
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="watermarking-backend"' \
  --project=watermarking-4a428 --limit=30 --freshness=10m

# Health check
curl https://watermarking-backend-78940960204.us-central1.run.app/health
```

**Build prerequisite**: Copy C++ library before building:

```bash
cp -r ../watermarking-functions/*.cpp ./watermarking-functions/
cp -r ../watermarking-functions/*.hpp ./watermarking-functions/
```

## Architecture

Backend processing service: Firestore listener → GCS download → C++ processing → GCS upload → Firestore update

```text
listener.js          # Entry point, HTTP server for Cloud Run health checks
  └── task-queue.js  # Firestore listener for /tasks collection
        ├── marking-queues.js    # Runs ./mark-image binary
        ├── detection-queues.js  # Runs ./detect-wm binary
        └── misc-queues.js       # Serving URLs, user verification

firebase-admin-singleton.js  # Firebase/Firestore initialization
storage-helper.js            # GCS upload/download operations
tools.js                     # Twilio SMS, serving URL helper
```

### C++ Binaries

- `./mark-image <filePath> <imageName> <message> <strength>` - Embeds watermark, outputs `{filePath}-marked.png`
- `./detect-wm <uid> <originalPath> <markedPath>` - Extracts watermark, outputs `/tmp/{uid}.json`

### Task Flow

1. Flutter app writes to `/tasks` with `status: 'pending'`
2. `task-queue.js` picks up task, sets `status: 'processing'`
3. Handler downloads from GCS, runs C++ binary, uploads result
4. Updates Firestore, sets `status: 'completed'` or `'failed'`

## Firestore Collections

```
/tasks              - type: 'mark' | 'detect' | 'get_serving_url', status: pending/processing/completed/failed
/originalImages     - userId, name, path, servingUrl
/markedImages       - originalImageId, userId, message, strength, path, servingUrl, progress
/detecting/{userId} - progress, isDetecting, results
```

## Configuration

- **Firebase Project**: `watermarking-4a428`
- **GCS Bucket**: `watermarking-4a428.firebasestorage.app`
- **Service Account**: `keys/firebase-service-account.json`
- **Deployed URL**: <https://watermarking-backend-78940960204.us-central1.run.app>

## Current Status (Dec 2025)

**BLOCKING**: Marking is extremely slow on CPU. A 4-character message on a small image takes hours, hitting Cloud Run's 1-hour timeout.

**Root cause**: `insertMark()` in `WatermarkDetection.cpp` does 2 full-image DFTs per character. For a 1000×1000 image, each DFT is ~20M operations.

### Optimization Options (discuss with Andrew Tirkel first)

| Optimization | Speedup | Notes |
|--------------|---------|-------|
| **Batch watermarks in freq domain** | ~Nx | Single DFT for all characters instead of 2N DFTs |
| Use optimal DFT size (power of 2) | ~2x | No quality impact |
| Downsample to 512×512 | ~4x | Slight quality reduction |
| GPU acceleration (CUDA) | ~10-100x | High effort, use Cloud Run GPU |

The batching optimization is mathematically equivalent (addition is linear in frequency domain) and provides the biggest win.

## TODO

- [ ] **Optimize marking performance** (discuss with Andrew Tirkel)
- [ ] Test detection flow
- [ ] Add retry logic for failed tasks

## Dockerfile Strategy

Three Dockerfiles for different use cases:
- `Dockerfile` - Standalone full build (good for fresh deploys)
- `Dockerfile.base` - Base image with compiled C++ binaries (slow build, rarely changes)
- `Dockerfile.cloudrun` - Inherits from base, adds JS (fast build for code changes)
