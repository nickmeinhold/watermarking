# watermarking-docker

Backend processing service for watermark embedding and detection. Listens to Firestore task queue, processes images with C++ OpenCV algorithms, uploads results to Cloud Storage.

## Deployment

**Cloud Run**: <https://watermarking-backend-78940960204.us-central1.run.app>

### Build & Deploy

```bash
# Build and push (AMD64 required for Cloud Run)
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
curl https://watermarking-backend-78940960204.us-central1.run.app/
```

## Tech Stack

- **Runtime**: Node.js
- **Image Processing**: C++ with OpenCV
- **Queue**: Custom Firestore listener
- **Storage**: Google Cloud Storage
- **Deployment**: Docker on Cloud Run

## Configuration

- **Firebase Project**: `watermarking-4a428`
- **GCS Bucket**: `watermarking-4a428.firebasestorage.app`
- **Service Account**: `keys/firebase-service-account.json`

## Task Types

| Type | Description |
| ------ | ------------- |
| `mark` | Embed watermark message into image |
| `detect` | Extract watermark from captured image |
| `get_serving_url` | Generate public URL for uploaded image |

## Firestore Collections

```sh
/tasks              - Processing queue (pending → processing → completed)
/originalImages     - Uploaded original images
/markedImages       - Watermarked output images
/detecting/{userId} - Detection progress state
```

## Storage Paths

| Path Pattern | Purpose |
|--------------|---------|
| `original-images/{userId}/{fileName}` | Uploaded original images |
| `marked-images/{userId}/{timestamp}/{baseName}.png` | Processed watermarked images |
| `detecting-images/{userId}/{itemId}` | Captured images for detection |

**Note**: Marked image filenames have their extension stripped before `.png` is added to avoid double extensions like `image.png.png`.

## Known Issues

### Legacy Double Extension Bug

Marked images created before Jan 2026 may have broken `servingUrl` references due to a bug that created paths like `image.png.png`. These images show "Error loading image" in the web app. **Fix**: Delete the broken marked image and re-apply the watermark.
