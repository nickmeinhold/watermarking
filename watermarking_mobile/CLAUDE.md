# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Flutter mobile app for watermark detection. Users capture/select images with suspected watermarks, the app performs local rectangle detection and perspective correction, uploads to Firebase, and a backend service extracts and decodes the watermark.

## Build & Run

```bash
# Setup
flutter pub get

# iOS (requires physical device for ARKit)
cd ios && pod update && cd ..
flutter run -d ios

# Android (mock mode enabled by default for development)
flutter run -d android

# Run Android instrumented tests (requires device/emulator)
cd android && ./gradlew connectedAndroidTest
```

### Test Mode (Android)

Two flags control test/development mode:

**1. Auth Bypass** - Skip Firebase authentication (`lib/main.dart`):
```dart
const bool kBypassAuth = true;  // Skips Google Sign-In, shows TestModeAppWidget
```

**2. Mock Detection** - Skip OpenCV (`MainActivity.kt:42`):
```kotlin
private const val USE_MOCK_DETECTION = true  // false for real OpenCV
```

Or from Flutter at runtime:
```dart
await methodChannel.invokeMethod('setMockMode', {'enabled': true});
```

### Build APK

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Install on connected device
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Architecture

### Platform-Specific Detection

| Platform | Detection Method | Camera | Status |
|----------|-----------------|--------|--------|
| iOS | Vision Framework + ARKit | Live camera + accumulation | Production |
| Android | OpenCV 4.9.0 | Gallery picker only | Development |

### Method Channel

Channel: `watermarking.enspyr.co/detect`

| Method | Description |
|--------|-------------|
| `startDetection` | Opens camera (iOS) or gallery (Android), returns file path |
| `setMockMode` | Android only: toggle mock detection |
| `getServiceInfo` | Android only: returns current service name |
| `dismiss` | Dismisses detection UI |

### Android Detection Architecture

```
MainActivity.kt
       │ uses (via interface)
       ▼
DetectionService (interface)
       │
   ┌───┴───┐
   ▼       ▼
Real    Mock
(OpenCV) (Fake)
   │
   ├── RectangleDetector.kt   [55% confidence]
   ├── CornerOrderer.kt       [60% confidence]
   └── PerspectiveCorrector.kt [80% confidence]
```

See `MODULE_STRUCTURE.md` for detailed diagrams and `KNOWN_ISSUES.md` for limitations.

### Flutter Test Mode UI

When `kBypassAuth = true`, the app shows `TestModeAppWidget` (`lib/views/app.dart`) which:
- Bypasses Firebase entirely
- Provides standalone gallery → detect → show result flow
- Stores results locally (not in Firebase)
- Uses Material 3 design

### Android Files

```
android/app/src/main/kotlin/co/enspyr/watermarking_mobile/
├── MainActivity.kt              # Method channel, orchestration (extends FlutterFragmentActivity)
└── detection/
    ├── DetectionService.kt      # Interface
    ├── RealDetectionService.kt  # OpenCV implementation
    ├── MockDetectionService.kt  # Fake results for testing
    ├── RectangleDetector.kt     # Canny + contour detection
    ├── CornerOrderer.kt         # Orders corners TL/TR/BR/BL
    └── PerspectiveCorrector.kt  # Perspective warp
```

### iOS Files

```
ios/Runner/
├── AppDelegate.swift             # Method channel, CIFilter registration
├── DetectionViewController.swift # ARKit session, image accumulation
├── RectangleDetector.swift       # Vision VNDetectRectanglesRequest
├── Utilities.swift               # Custom WeightedCombine CIFilter
└── Kernels.metal                 # Metal shaders for blending
```

### Shared Flutter Code

Most business logic is in `watermarking_core` package (sibling directory):
- `redux/` - State management (actions, reducers, middleware)
- `models/` - Data models (AppState, DetectionItem, etc.)
- `services/` - Firebase wrappers (auth, database, storage)
- `widgets/` - Shared visualization widgets (11 chart cards)

## Detection Flow

```
Flutter: ActionPerformExtraction
    │
    ▼
DeviceService.performExtraction()
    │
    ├─► iOS: ARKit camera → Vision detection → Metal accumulation → PNG
    │
    └─► Android: Gallery picker → OpenCV detection → Perspective warp → PNG
    │
    ▼
Flutter: ActionProcessExtraction(filePath)
    │
    ▼
Upload to Firebase Storage → Create Firestore task → Backend processes
    │
    ▼
ActionSetDetectionItems (from Firebase subscription)
```

## Firebase Schema

| Collection | Purpose |
|------------|---------|
| `detecting/{userId}` | Detection status tracking |
| `tasks/{taskId}` | Backend queue entries |
| `detectionItems/{itemId}` | Final results with statistics |
| `originalImages/{docId}` | Original uploaded images |
| `markedImages/{docId}` | Watermarked image records |

## Key Dependencies

### Android (build.gradle)
- `org.opencv:opencv:4.9.0` - Rectangle detection
- `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3` - Async processing
- `androidx.activity:activity-ktx:1.8.2` - Activity result APIs

### Flutter (pubspec.yaml)
- `firebase_*` - Firebase integration
- `flutter_redux, redux_epics` - State management
- `fl_chart` - Detection visualization charts

## Tunable Parameters (Android)

In `RectangleDetector.kt`:

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `cannyLow` | 50.0 | Edge detection sensitivity (lower) |
| `cannyHigh` | 150.0 | Edge detection sensitivity (upper) |
| `approxEpsilon` | 0.02 | Polygon approximation tolerance |
| `minAreaRatio` | 0.25 | Minimum rectangle size (% of image) |
| `quadratureTolerance` | 20.0 | Corner angle tolerance (degrees) |

## Related Documentation

- `PLAN.md` - Implementation plan with confidence assessments
- `MODULE_STRUCTURE.md` - Detailed architecture diagrams
- `KNOWN_ISSUES.md` - Unsolved problems and limitations
