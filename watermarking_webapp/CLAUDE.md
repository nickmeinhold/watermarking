# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run locally
flutter run -d chrome

# Build & deploy to Firebase Hosting
firebase deploy --only hosting
```

## Overview

Flutter web application for managing watermarked images - upload originals, apply watermarks, and view detection results.

## Role in System

Web interface component of the watermarking system. See `../CLAUDE.md` for full system architecture.

```
┌─────────────────┐
│ watermarking_   │ ← YOU ARE HERE
│ webapp          │   Web interface for image management
│ (Flutter Web)   │
└────────┬────────┘
         │
         ├─→ Firebase (watermarking-4a428)
         │   • Cloud Firestore: user data, image metadata, task queues
         │   • Storage: original & marked images
         │   • Auth: Google Sign-In
         │
         └─→ watermarking_core (shared package)
             • Redux state management
             • Firebase service wrappers
             • Data models
```

## Tech Stack

- **Framework**: Flutter 3.x (Web)
- **State**: Redux + Redux Epics
- **Routing**: go_router
- **Auth**: Firebase Auth + Google Sign-In
- **Backend**: Cloud Firestore + Storage
- **UI**: Material Design 3

## Routes

| Route | Page | Purpose |
|-------|------|---------|
| `/opening` | OpeningPage | Google Sign-In landing |
| `/original` | OriginalImagesPage | Upload and manage originals |
| `/marked` | MarkedImagesPage | Apply watermarks, view results, trigger detection |
| `/admin` | AdminPage | Administrative functions |

Note: Detection UI is integrated into MarkedImagesPage (not a separate route).

## Architecture

### State Management

Redux pattern with epics for async operations:

- **Store**: Single `AppState` with slices for user, originals, marked images
- **Middleware**: Custom + Epic middleware for Firebase operations
- **Actions**: `ActionUploadOriginalImage`, `ActionMarkImage`, `ActionSetSelectedImage`, etc.

### Shared Code

Depends on `watermarking_core` package (`../watermarking_core`) which provides:

- `AppState`, reducers, actions
- `AuthService`, `DatabaseService`, `StorageService`
- Data models: `UserModel`, `OriginalImageReference`, `MarkedImageReference`, `DetectionItem`
- Platform-specific `DeviceService` interface
- Detection visualization widgets (11 chart cards)

This app provides `WebDeviceService` implementation for web-specific file picking.

### Firebase Integration

Project: `watermarking-4a428`

**Firestore** collections:
```
/users/{userId}              - user profile
/originalImages/{imageId}    - original image metadata
/markedImages/{imageId}      - marked image metadata & processing status
/tasks/{taskId}              - processing tasks (mark, detect, get_serving_url)
/detecting/{userId}          - detection progress state
/detectionItems/{itemId}     - detection results with statistics
```

**Storage** paths:
- `original-images/{userId}/` - uploaded source images
- `marked-images/{userId}/` - watermarked outputs
- `detecting-images/{userId}/` - captured images for detection

## Build & Deploy

### Development
```bash
flutter run -d chrome
```

### Production Build
```bash
# Manual build
flutter build web --release --source-maps

# Or use the build script (includes dart-define flags)
./build_web.sh
```

### Deploy to Firebase Hosting
```bash
firebase deploy --only hosting
# Note: predeploy hook runs build_web.sh automatically
```

Build output: `build/web/`

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, routing, Redux store setup, AppShell navigation |
| `lib/services/web_device_service.dart` | Web-specific file picker implementation |
| `lib/views/original_images_page.dart` | Upload UI with progress, delete functionality |
| `lib/views/marked_images_page.dart` | Watermark dialog, detection trigger, results display |
| `lib/views/detection_detail_dialog.dart` | Full detection statistics in responsive dialog |
| `build_web.sh` | Production build with dart-define flags |

## Related Projects

- `../watermarking_core/` - Shared Flutter package
- `../watermarking_mobile/` - iOS app (camera capture & detection)
- `../watermarking-docker/` - Backend (C++ mark/detect processing)
- `../watermarking-functions/` - C++ algorithms
