# CLAUDE.md - Watermarking Mobile App Reference

## Purpose
Flutter mobile app for watermark detection. Users capture images with suspected watermarks, the app performs local rectangle detection and perspective correction (iOS only), uploads to Firebase, and a backend service extracts and decodes the watermark.

## Tech Stack
- **Flutter/Dart**: Cross-platform UI framework
- **Firebase**: Authentication (Google Sign-in), Realtime Database, Storage
- **Redux**: State management (flutter_redux, redux_epics, rxdart)
- **iOS Native**: ARKit, Vision Framework, Metal shaders, CoreImage
- **Android**: Basic Flutter app (NO native detection implemented)

## Architecture

### Directory Structure
```
lib/
├── main.dart                 # App entry point, store setup
├── models/                   # Data models and view models (in watermarking_core)
├── redux/                    # State management (in watermarking_core)
├── services/                 # External integrations (in watermarking_core)
├── views/                    # UI components
│   ├── app.dart             # Root widget with StoreProvider
│   ├── home_page.dart       # Detection history list with stepper
│   ├── detection_card.dart  # Swipeable detection card with thumbnail
│   ├── detection_detail_page.dart # 11 visualization charts
│   ├── signin_page.dart     # Google Sign-in UI
│   └── select_image_*.dart  # Image selection UI
└── utilities/                # Helper functions

ios/Runner/
├── AppDelegate.swift         # Method channel setup, custom filter registration
├── DetectionViewController.swift # ARKit session, image accumulator
├── RectangleDetector.swift   # Vision Framework rectangle detection
├── Utilities.swift           # Custom CIFilter (WeightedCombine)
└── Kernels.metal            # Metal shader for weighted image blending
```

## Key Files

### Flutter/Dart
- **lib/main.dart**: Redux store initialization with services and middleware
- **lib/models/app_state.dart**: Root state (user, originals, detections, problems)
- **lib/redux/actions.dart**: All action types (signin, extraction, upload, etc.)
- **lib/redux/middleware.dart**: Side effects for extraction, upload, database writes
- **lib/services/device_service.dart**: Platform channel `watermarking.enspyr.co/detect`
- **lib/services/storage_service.dart**: Firebase Storage upload with progress tracking
- **lib/services/database_service.dart**: Realtime Database subscriptions

### iOS Native
- **ios/Runner/AppDelegate.swift**: Registers custom `WeightedCombine` CIFilter, sets up method channel
- **ios/Runner/DetectionViewController.swift**: ARKit session, accumulates detected rectangles
- **ios/Runner/RectangleDetector.swift**: Vision VNDetectRectanglesRequest + perspective correction
- **ios/Runner/Utilities.swift**: Custom CIFilter using Metal kernels for weighted image blending
- **ios/Runner/Kernels.metal**: Metal Shading Language kernels (`weightColor`, `blendWeighted`)

## iOS Native Code Deep Dive

### Rectangle Detection Flow
1. **RectangleDetector.swift** runs a timer (0.1s interval) to capture ARKit frames
2. **Vision Framework** (`VNDetectRectanglesRequest`) detects rectangles with:
   - Minimum size: 0.25
   - Minimum confidence: 0.90
   - Minimum aspect ratio: 0.3
   - Quadrature tolerance: 20
3. **Perspective Correction**: `CIPerspectiveCorrection` filter straightens detected rectangle
4. **Scaling**: `CILanczosScaleTransform` resizes to 512px width

### Image Accumulation (Noise Reduction)
- **DetectionViewController** accumulates multiple rectangle detections over time
- Uses custom `WeightedCombine` CIFilter with Metal shader
- **CIImageAccumulator** (512x512, ARGB8) stores running average
- Formula: `output = (foreground * 1/(n+1)) + (background * n/(n+1))` where n = numCombined
- Reduces noise from camera jitter and lighting variations

### Metal Shaders (Kernels.metal)
- **weightColor**: Multiplies each pixel by weight
- **blendWeighted**: Adds weighted foreground + background
- Compiled to `default.metallib` and loaded at runtime

### ARKit Setup
- **ARImageTrackingConfiguration**: No reference images (empty set)
- Maximum tracked images: 1
- Camera permission required (NSCameraUsageDescription in Info.plist)

### Method Channel
- **Channel name**: `watermarking.enspyr.co/detect`
- **Methods**:
  - `startDetection(width, height)`: Presents DetectionViewController, returns file path
  - `dismiss()`: Dismisses DetectionViewController
- Tap gesture on accumulated image saves PNG to app documents directory

## Detection Flow

### Local Processing (iOS Only)
1. User selects original image from Firebase
2. Taps button to start detection
3. **ActionPerformExtraction** dispatched
4. **DeviceService** calls `startDetection()` via method channel
5. **DetectionViewController** presented:
   - ARKit session captures camera frames
   - Vision detects rectangles (watermarked area)
   - Perspective correction applied
   - Multiple detections accumulated using Metal shader
6. User taps accumulated image to save
7. Image saved to documents directory, file path returned
8. **ActionProcessExtraction** dispatched with file path

### Upload & Backend Detection
1. **Middleware** generates unique ID, dispatches **ActionAddDetectionItem**
2. **ActionStartUpload** dispatched
3. **StorageService** uploads to `detecting-images/{userId}/{itemId}`
4. Upload progress tracked via Firebase Storage events
5. On **ActionSetUploadSuccess**, middleware calls **DatabaseService.addDetectingEntry()**
6. Database entry created:
   - `detecting/incomplete/{userId}`: status tracking
   - `queue/tasks`: backend task queue
7. Backend cloud function processes:
   - Downloads original + marked image
   - Performs watermark extraction
   - Writes result to `detection-items/{userId}/{itemId}`
8. **DatabaseService** subscriptions update app state with results

### State Flow
```
ActionPerformExtraction
  -> DeviceService.performExtraction()
  -> ActionProcessExtraction(filePath)
  -> ActionAddDetectionItem(id, path, bytes)
  -> ActionStartUpload(id, path)
  -> StorageService.startUpload()
  -> ActionSetUploadSuccess(id)
  -> DatabaseService.addDetectingEntry()
  -> Backend processes
  -> ActionSetDetectionItems (from Firebase subscription)
```

## Detection Visualization UI

When a detection completes, tapping the detection card opens `detection_detail_page.dart` with 11 visualization cards:

### Charts (using fl_chart package)
1. **Result Card** - Image thumbnail, decoded message, confidence badge, detected/not detected chip
2. **Signal Strength Gauge** - Circular progress showing min PSNR as percentage of threshold (6.0)
3. **PSNR Bar Chart** - Per-sequence PSNR values, bars colored green (above) / red (below) threshold
4. **Timing Pie Chart** - Processing time breakdown: image load, extraction, correlation phases
5. **Technical Details** - Table showing image size, prime size, threshold, correlation matrix stats
6. **Peak Positions Scatter** - (X, Y) correlation peak locations in frequency domain (0 to primeSize)
7. **PSNR Distribution Histogram** - Frequency distribution of PSNR values across 10 bins
8. **Peak Value vs RMS Scatter** - Signal quality: higher peak + lower RMS = stronger detection
9. **Shift Values Line Chart** - Detected shifts per sequence (encodes the hidden message)
10. **Message Decoding Card** - Decoded message display, confidence grid with tooltips, shift details table
11. **Image Comparison** - Side-by-side original watermarked image vs captured/extracted image

### Key UI Components
- **DetectionCard** (`detection_card.dart`): Dismissible card with swipe-to-delete, image thumbnail, confidence indicator
- **DetectionSteps** (`home_page.dart`): Stepper showing Upload → Setup → Detect progress with error display

## Android Implementation Status
**Android is NOT implemented**. The MainActivity.kt is a basic Flutter stub with no native code. Rectangle detection, ARKit integration, and Metal shaders are iOS-only. To implement Android, you would need:
- Replace ARKit with ARCore
- Replace Vision Framework with ML Kit or custom OpenCV rectangle detection
- Replace Metal shaders with OpenGL/Vulkan or RenderScript
- Implement platform channel handler in MainActivity.kt

## Build & Run

### Prerequisites
- Flutter SDK (targeting Dart SDK >=2.3.0 <3.0.0)
- iOS: Xcode, CocoaPods
- Firebase project with Auth, Database, Storage enabled
- GoogleService-Info.plist (iOS) configured

### Setup
```bash
cd watermarking_mobile
flutter pub get
cd ios
pod update  # Install native dependencies
cd ..
```

### Run
```bash
# iOS (required for detection features)
flutter run -d "iPhone 14"  # or physical device

# Android (basic UI only, no detection)
flutter run -d <android-device>
```

### Notes
- iOS targets iOS 12+ (for ARKit 2.0)
- Camera permission required (prompts on first launch)
- Requires physical device (ARKit doesn't work in simulator)

## Dependencies

### Flutter Packages (pubspec.yaml)
- **firebase_core, firebase_auth, firebase_database, firebase_storage**: Firebase integration
- **google_sign_in**: Google authentication
- **flutter_redux, redux, redux_epics**: Redux state management
- **rxdart**: Reactive streams
- **path_provider**: File system access
- **flutter_svg**: SVG rendering
- **fl_chart**: Charts for detection visualization (bar, pie, scatter, line)

### iOS Native (Podfile)
- Standard Flutter pods + Firebase pods (auto-managed via .flutter-plugins)

### Dev Dependencies
- **flutter_test, flutter_driver**: Testing
- **mockito**: Mocking for tests
- **redux_remote_devtools**: Redux debugging

## Common Development Tasks

### Adding a New Action
1. Add action class to `lib/redux/actions.dart`
2. Add case to reducer in `lib/redux/reducers.dart`
3. If side effects needed, add middleware to `lib/redux/middleware.dart`
4. Dispatch from UI via `StoreProvider.of(context).dispatch()`

### Modifying Detection Logic
- **Rectangle detection params**: `ios/Runner/RectangleDetector.swift` (VNDetectRectanglesRequest)
- **Accumulation logic**: `ios/Runner/DetectionViewController.swift` (filter setup)
- **Blending weights**: `ios/Runner/Utilities.swift` (WeightedCombineFilter.outputImage)

### Firebase Schema
- `users/{userId}`: name, email
- `original-images/{userId}/{imageId}`: name, path, servingUrl
- `detection-items/{userId}/{itemId}`: progress, result
- `detecting/incomplete/{userId}`: itemId, progress, isDetecting, pathOriginal, pathMarked
- `queue/tasks`: _state, uid, pathOriginal, pathMarked

## Known Issues & TODOs
- Android detection not implemented (see README TODO notes)
- `performFakeExtraction()` method exists but commented out in DeviceService
- Image size not stored in OriginalImageReference (TODO comment in actions.dart)
