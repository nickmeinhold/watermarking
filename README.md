# Watermarking System

Digital watermarking system for embedding and detecting invisible messages in images that survive print-and-scan.

## Architecture

```
                      Firebase: watermarking-4a428
                    (Cloud Firestore + Storage + Auth)
                                    |
            +-----------------------+-----------------------+
            |                       |                       |
   watermarking_mobile      watermarking_webapp    watermarking-docker
      (Flutter/iOS)           (Flutter Web)         (Node.js + C++)
            |                       |                       |
      Local rectangle          Web interface          Backend processing
      detection + upload       for management         mark & detect engines
                                                            |
                                                   watermarking-functions
                                                       (C++ library)
```

## Projects

| Directory | Purpose | Tech Stack |
|-----------|---------|------------|
| `watermarking_mobile/` | Mobile app - captures images, detects rectangles (iOS only), uploads for processing | Flutter, ARKit, Vision Framework, Metal |
| `watermarking_webapp/` | Web interface - upload originals, view marked images, trigger detection | Flutter Web, Firebase, Material 3 |
| `watermarking-docker/` | Backend - queue-based processing, runs C++ mark/detect binaries | Node.js, Docker, Firebase Queue |
| `watermarking-functions/` | Core algorithms - DFT-based watermark embedding/extraction | C++, OpenCV |

## Detection Flow

1. **iOS app** uses Vision Framework + ARKit to detect and perspective-correct a watermarked image from camera
2. **App uploads** the captured image to Firebase Storage
3. **App writes** a task to Cloud Firestore `tasks` collection
4. **Docker backend** picks up the task, downloads images from GCS
5. **C++ detect binary** extracts the hidden message using correlation analysis
6. **Results** written back to Firestore, app displays the decoded message

### Detection Data Structures

**DetectionItem** (core model in `watermarking_core/lib/models/detection_item.dart`):
- `id`, `started`, `progress`, `result`, `confidence`, `error`
- `originalRef`: link to original image
- `extractedRef`: the captured/detected image with `localPath`, `remotePath`, `servingUrl`, upload progress

### Detailed Detection Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. User selects original image → ActionSetSelectedImage            │
│  2. User taps "Detect" → ActionPerformExtraction                    │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  3. iOS Vision/ARKit detects rectangle, perspective corrects       │
│     Saves PNG locally → returns file path                          │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  4. ActionProcessExtraction                                         │
│     → Generate Firestore ID                                         │
│     → ActionAddDetectionItem (adds to local Redux state)            │
│     → ActionStartUpload                                             │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  5. Upload to Storage: detecting-images/{userId}/{itemId}          │
│     → ActionSetUploadProgress → ActionSetUploadSuccess              │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  6. Create Firestore task (database_service.dart:addDetectingEntry) │
│                                                                     │
│     detecting/{userId}:                                             │
│       { itemId, progress, isDetecting, pathOriginal, pathMarked }   │
│                                                                     │
│     tasks/{auto-id}:                                                │
│       { type: "detect", status: "pending", userId, paths... }       │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  7. Backend picks up task, runs C++ detect, updates Firestore       │
│     → detectionItems/{itemId} with result, confidence               │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  8. App listens to detectionItems → ActionSetDetectionItems         │
│     → UI shows result/confidence                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Detection Files

| File | Purpose |
|------|---------|
| `watermarking_core/lib/redux/middleware.dart` | Orchestrates flow via `_performExtraction()`, `_processExtraction()`, `_startWatermarkDetection()` |
| `watermarking_core/lib/services/database_service.dart` | `addDetectingEntry()` creates Firestore docs |
| `watermarking_core/lib/services/storage_service.dart` | Handles upload to `detecting-images/` |
| `watermarking_mobile/ios/Runner/DetectionViewController.swift` | iOS rectangle detection UI |

### Firestore Collections

| Collection | Purpose |
|------------|---------|
| `detecting/{userId}` | Status tracking for current detection |
| `tasks/{taskId}` | Queue entry for backend processing |
| `detectionItems/{itemId}` | Final detection results |
| `originalImages/{docId}` | Original uploaded images |
| `markedImages/{docId}` | Watermarked image records |

## Marking Flow

1. **Web app** uploads an original image to Firebase Storage
2. **Task queued** in Firestore `tasks` collection
3. **Docker backend** downloads image, runs C++ mark binary
4. **Marked image** uploaded to GCS, metadata updated in Firestore

### Marking Data Structures

**MarkedImageReference** (core model in `watermarking_core/lib/models/marked_image_reference.dart`):
- `id`, `message`, `name`, `strength`, `progress`
- `path`: GCS path to marked image
- `servingUrl`: CDN URL for the marked image
- `isProcessing`: true when `servingUrl` is null/empty

**OriginalImageReference** contains a `List<MarkedImageReference> markedImages` for all marked versions.

### Detailed Marking Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. User selects original image, clicks "Apply Watermark"          │
│     Fills message + strength → ActionMarkImage dispatched          │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  2. Middleware: _markImage calls databaseService.addMarkingTask()  │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  3. Create Firestore documents (database_service.dart)             │
│                                                                     │
│     markedImages/{markedImageId}:                                   │
│       { originalImageId, userId, message, name, strength,          │
│         progress: "Queued", createdAt }                            │
│                                                                     │
│     tasks/{auto-id}:                                                │
│       { type: "mark", status: "pending", userId, markedImageId,    │
│         originalImageId, name, path, message, strength }           │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  4. Backend (marking-queues.js) picks up task                      │
│     → Downloads original from GCS                                   │
│     → Runs C++ mark binary with progress updates                   │
│     → Uploads marked image to marked-images/{userId}/{ts}/         │
│     → Generates signed URL (10 year validity)                      │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  5. Backend updates markedImages/{markedImageId}:                  │
│       { path, servingUrl, progress: null, processedAt }            │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  6. App listens to markedImages → ActionUpdateMarkedImages         │
│     → UI shows marked image with servingUrl                        │
└─────────────────────────────────────────────────────────────────────┘
```

### Progress Status Values

The `progress` field provides real-time feedback:
```
"Queued" → "Downloading image..." → "Loading image..." →
"Embedding watermark (1/N)" → "Compressing image..." →
"Uploading marked image..." → "Generating URL..." → null (complete)
```

### Key Marking Files

| File | Purpose |
|------|---------|
| `watermarking_core/lib/models/marked_image_reference.dart` | Marked image data model |
| `watermarking_core/lib/redux/middleware.dart` | `_markImage` middleware handler |
| `watermarking_core/lib/services/database_service.dart` | `addMarkingTask()` creates Firestore docs |
| `watermarking_webapp/lib/views/marked_images_page.dart` | UI for marking dialog and displaying results |
| `watermarking-docker/marking-queues.js` | Backend task processing |

### Firestore Collections (Marking)

| Collection | Purpose |
|------------|---------|
| `markedImages/{markedImageId}` | Marked image metadata + processing status |
| `tasks/{taskId}` | Queue entry for backend processing |
| `originalImages/{docId}` | Original uploaded images |

### Storage Paths

| Path Pattern | Purpose |
|--------------|---------|
| `original-images/{userId}/{fileName}` | Original uploaded images |
| `marked-images/{userId}/{timestamp}/{fileName}.png` | Processed watermarked images |

## Build Notes

- **watermarking-docker** builds `watermarking-functions` from the sibling directory (managed via Docker build context context).

- **Android** detection is not implemented - only iOS has native rectangle detection code

## Firebase Project

All components connect to: `watermarking-4a428`
- Firestore: `watermarking-4a428`
- Storage: `watermarking-4a428.firebasestorage.app`
- App Engine (serving URLs): `watermarking-4a428.appspot.com`

## Status

Archived. iOS-first project with functional web and backend components.
