# Watermarking Mobile

Flutter iOS app for detecting invisible watermarks in printed images.

## Features

- **Rectangle Detection**: Uses iOS Vision Framework + ARKit to detect and perspective-correct watermarked images from camera
- **Image Accumulation**: Metal shaders reduce noise by averaging multiple camera frames
- **Cloud Processing**: Uploads captured images to Firebase, backend extracts watermark using C++ correlation analysis
- **Visualization**: 11 interactive charts showing detection statistics (PSNR, timing, correlation, etc.)
- **Swipe-to-Delete**: Detection history cards can be dismissed with swipe gesture

## Requirements

- iOS 12+ (for ARKit 2.0)
- Physical iOS device (ARKit doesn't work in simulator)
- Flutter SDK 3.0+
- Xcode with CocoaPods

## Setup

```bash
flutter pub get
cd ios && pod update && cd ..
```

## Run

```bash
flutter run -d <ios-device-id>
```

## Architecture

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation including:
- Redux state management pattern
- iOS native rectangle detection implementation
- Detection flow from capture to visualization
- All 11 visualization charts

## Note

Android detection is **not implemented**. The Android build runs but has no native camera/rectangle detection code.
