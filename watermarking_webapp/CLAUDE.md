# Watermarking Web App (Flutter)

Flutter web application for managing watermarked images - upload originals, view marked images, and trigger detection tasks.

## Role in System

This is the web interface component of the watermarking system. See `../CLAUDE.md` for full system architecture.

```sh
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

## Features

| Page | Route | Purpose |
| ------ | ------- | --------- |
| Opening | `/opening` | Google Sign-In landing page |
| Original Images | `/original` | Upload and manage original images |
| Marked Images | `/marked` | View watermarked outputs from backend |
| Detect | `/detect` | Trigger detection tasks, view results |
| Admin | `/admin` | Administrative functions |

## Architecture

### State Management

Uses Redux pattern with epics for async operations:

- **Store**: Single `AppState` with slices for user, originals, marked images, etc.
- **Middleware**: Custom middleware + Epic middleware for Firebase operations
- **Actions**: Dispatch actions like `ActionUploadOriginalImage`, `ActionSetSelectedImage`

### Shared Code

Depends on `watermarking_core` package (sibling directory) which provides:

- `AppState`, reducers, actions
- `AuthService`, `DatabaseService`, `StorageService`
- Data models: `UserModel`, `OriginalImageReference`, etc.
- Platform-specific `DeviceService` interface

This app provides `WebDeviceService` implementation for web-specific functionality.

### Firebase Integration

Connects to project: `watermarking-4a428`

**Cloud Firestore** collections:

```sh
/users/{userId}              - user profile data
/originalImages/{imageId}    - original image metadata (filtered by userId)
/markedImages/{imageId}      - marked image metadata & results
/tasks/{taskId}              - processing tasks (mark, detect, get_serving_url)
/detecting/{userId}          - detection progress state
/detectionItems/{itemId}     - detection results
```

**Storage** paths:

- `original-images/{userId}/` - uploaded source images
- `marked-images/{userId}/` - watermarked outputs
- `detecting-images/{userId}/` - images captured for detection

## Workflows

### Upload & Mark

1. User uploads image via file picker on `/original` page
2. App dispatches `ActionUploadOriginalImage`
3. Middleware uploads to Storage, writes metadata to Firestore, creates `get_serving_url` task
4. Backend (watermarking-docker) picks up task, generates CDN serving URL
5. User selects image and triggers marking with message/strength
6. Backend runs C++ mark binary, uploads marked image
7. Marked image appears in `/marked` page

### Detection

1. User uploads captured image on `/detect` page
2. App queues detection task in Firestore
3. Backend runs C++ detect binary
4. Results written back to Firestore
5. Decoded message displayed in UI

## Development

### Prerequisites

- Flutter SDK 3.x
- `watermarking_core` package available at `../watermarking_core`
- Firebase project configured (see `firebase_options.dart`)

### Run

```bash
flutter run -d chrome
```

### Build

```bash
flutter build web
```

Output in `build/web/` can be deployed to Firebase Hosting or any static host.

## Related Projects

- `../watermarking_mobile/` - Flutter iOS app (image capture & detection)
- `../watermarking-docker/` - Node.js backend (processes mark/detect tasks)
- `../watermarking-functions/` - C++ algorithms (DFT watermarking)
- `../watermarking_core/` - Shared Flutter package (state, models, services)
