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

## Marking Flow

1. **Web app** uploads an original image to Firebase Storage
2. **Task queued** in Firestore `tasks` collection
3. **Docker backend** downloads image, runs C++ mark binary
4. **Marked image** uploaded to GCS, metadata updated in Firestore

## Build Notes

- **watermarking-docker** expects `watermarking-functions/` subdirectory to contain the C++ library. Currently empty - copy from sibling directory before building:
  ```bash
  cp -r watermarking-functions/* watermarking-docker/watermarking-functions/
  ```

- **Android** detection is not implemented - only iOS has native rectangle detection code

## Firebase Project

All components connect to: `watermarking-4a428`
- Firestore: `watermarking-4a428`
- Storage: `watermarking-4a428.firebasestorage.app`
- App Engine (serving URLs): `watermarking-4a428.appspot.com`

## Status

Archived. iOS-first project with functional web and backend components.
