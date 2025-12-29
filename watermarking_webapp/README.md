# Watermarking Web App

Flutter web application for managing digital watermarks - upload original images, view watermarked outputs, and trigger detection tasks.

## Overview

This is the web interface component of a digital watermarking system that embeds invisible messages in images that survive print-and-scan. The app connects to Firebase for authentication, storage, and real-time database operations.

## Features

| Page | Route | Description |
| ------ | ------- | ------------- |
| Opening | `/opening` | Google Sign-In landing page |
| Original Images | `/original` | Upload and manage original images |
| Marked Images | `/marked` | View watermarked outputs from backend processing |
| Detect | `/detect` | Trigger detection tasks and view decoded results |
| Admin | `/admin` | Administrative functions |

## Tech Stack

- **Framework**: Flutter 3.x (Web)
- **State Management**: Redux + Redux Epics
- **Routing**: go_router
- **Authentication**: Firebase Auth with Google Sign-In
- **Backend**: Firebase Realtime Database + Storage
- **UI**: Material Design 3

## Prerequisites

- Flutter SDK 3.0.0 or higher
- `watermarking_core` package available at `../watermarking_core`
- Firebase project configured (`watermarking-print-and-scan`)

## Getting Started

### Install dependencies

```bash
flutter pub get
```

### Run locally

```bash
flutter run -d chrome
```

### Build for production

```bash
flutter build web
```

Output is generated in `build/web/` and can be deployed to Firebase Hosting or any static host.

## Project Structure

```sh
lib/
├── main.dart                 # App entry point, routing, Redux store setup
├── firebase_options.dart     # Firebase configuration
├── services/
│   └── web_device_service.dart  # Web-specific device service implementation
└── views/
    ├── opening_page.dart     # Sign-in page
    ├── original_images_page.dart  # Upload originals
    ├── marked_images_page.dart    # View marked images
    ├── detect_page.dart      # Detection interface
    └── admin_page.dart       # Admin functions
```

## Architecture

### State Management

Uses Redux pattern with epics for async operations:

- **Store**: Single `AppState` with slices for user, originals, marked images
- **Middleware**: Custom middleware + Epic middleware for Firebase operations
- **Actions**: Dispatch actions like `ActionUploadOriginalImage`, `ActionSignin`

### Shared Code

Depends on `watermarking_core` package which provides:

- `AppState`, reducers, actions
- `AuthService`, `DatabaseService`, `StorageService`
- Data models: `UserModel`, `OriginalImageReference`
- Platform-specific `DeviceService` interface

## Firebase Project

Connects to: `watermarking-print-and-scan`

- Database: `https://watermarking-print-and-scan.firebaseio.com`
- Storage: `watermarking-print-and-scan.appspot.com`

## Related Projects

| Project | Purpose |
| --------- | --------- |
| `../watermarking_core/` | Shared Flutter package (state, models, services) |
| `../watermarking_mobile/` | Flutter iOS app (image capture & detection) |
| `../watermarking-docker/` | Node.js backend (processes mark/detect tasks) |
| `../watermarking-functions/` | C++ algorithms (DFT watermarking) |

## License

Private repository - all rights reserved.
