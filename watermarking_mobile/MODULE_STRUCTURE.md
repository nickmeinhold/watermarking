# Module Structure - Android Rectangle Detection

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FLUTTER LAYER                                   │
│                                                                             │
│    ┌─────────────────────────────────────────────────────────────────┐     │
│    │                    DeviceService (Dart)                          │     │
│    │                                                                  │     │
│    │   startDetection() ─────────────────────────► Method Channel    │     │
│    │                                               "watermarking.     │     │
│    │   ◄───────────────────────────────────────── enspyr.co/detect"  │     │
│    │   returns: filePath or error                                     │     │
│    └─────────────────────────────────────────────────────────────────┘     │
│                                    │                                        │
│                                    │ Platform Channel                       │
│                                    ▼                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     │
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ANDROID NATIVE LAYER                              │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                                                                        │ │
│  │                      MainActivity.kt [95%]                             │ │
│  │                                                                        │ │
│  │   ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │ │
│  │   │   Gallery   │───►│   Bitmap    │───►│   Detection Pipeline    │  │ │
│  │   │   Picker    │    │   Loaded    │    │   (orchestration)       │  │ │
│  │   └─────────────┘    └─────────────┘    └─────────────────────────┘  │ │
│  │                                                    │                   │ │
│  └────────────────────────────────────────────────────│───────────────────┘ │
│                                                       │                     │
│                                                       ▼                     │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                         DETECTION MODULE                               │ │
│  │                                                                        │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │   │                                                                  │ │ │
│  │   │                  RectangleDetector.kt [55%]                     │ │ │
│  │   │                                                                  │ │ │
│  │   │   Bitmap ──► Grayscale ──► Blur ──► Canny ──► Contours ──►     │ │ │
│  │   │              Polygons ──► Filter (size/aspect/angle) ──►        │ │ │
│  │   │              List<Point>?                                        │ │ │
│  │   │                                                                  │ │ │
│  │   │   Tunable: cannyLow, cannyHigh, blurKernel, epsilon,            │ │ │
│  │   │            minAreaRatio, maxAreaRatio, minAspectRatio,          │ │ │
│  │   │            quadratureTolerance                                   │ │ │
│  │   │                                                                  │ │ │
│  │   └─────────────────────────────────────────────────────────────────┘ │ │
│  │                              │                                         │ │
│  │                              │ List<Point> (4 corners, unordered)     │ │
│  │                              ▼                                         │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │   │                                                                  │ │ │
│  │   │                   CornerOrderer.kt [60%]                        │ │ │
│  │   │                                                                  │ │ │
│  │   │   List<Point> ──► Sort by sum (x+y) ──► topLeft, bottomRight   │ │ │
│  │   │                ──► Sort by diff (y-x) ──► topRight, bottomLeft  │ │ │
│  │   │                ──► OrderedCorners                                │ │ │
│  │   │                                                                  │ │ │
│  │   │   ⚠️  Known issue: fails at 45°+ rotation                       │ │ │
│  │   │                                                                  │ │ │
│  │   └─────────────────────────────────────────────────────────────────┘ │ │
│  │                              │                                         │ │
│  │                              │ OrderedCorners                          │ │
│  │                              ▼                                         │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │   │                                                                  │ │ │
│  │   │                PerspectiveCorrector.kt [80%]                    │ │ │
│  │   │                                                                  │ │ │
│  │   │   Bitmap + OrderedCorners ──► getPerspectiveTransform ──►       │ │ │
│  │   │   warpPerspective (Lanczos4) ──► Corrected Bitmap               │ │ │
│  │   │                                                                  │ │ │
│  │   │   ⚠️  Known issue: aspect ratio uses maxOf() edges              │ │ │
│  │   │                                                                  │ │ │
│  │   └─────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              │ Corrected Bitmap                            │
│                              ▼                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                          OUTPUT                                        │ │
│  │                                                                        │ │
│  │   Bitmap ──► PNG ──► Save to app cache ──► Return file path           │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Module Dependency Graph

```
                    ┌──────────────────────┐
                    │                      │
                    │   MainActivity.kt    │
                    │       [95%]          │
                    │                      │
                    └──────────┬───────────┘
                               │
                               │ uses (via interface)
                               ▼
                    ┌──────────────────────┐
                    │                      │
                    │  DetectionService    │◄─────────── INTERFACE
                    │    (interface)       │
                    │      [95%]           │
                    │                      │
                    └──────────┬───────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
              ▼                                 ▼
┌─────────────────────────┐       ┌─────────────────────────┐
│                         │       │                         │
│  RealDetectionService   │       │  MockDetectionService   │
│       [70%]             │       │       [95%]             │
│                         │       │                         │
│  Uses OpenCV for real   │       │  Returns fake results   │
│  rectangle detection    │       │  for testing/dev        │
│                         │       │                         │
└───────────┬─────────────┘       └─────────────────────────┘
            │
            │ uses
            │
┌───────────┼───────────────────────────────────┐
│           │                                   │
▼           ▼                                   ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│                  │ │                  │ │                  │
│ RectangleDetector│ │  CornerOrderer   │ │PerspectiveCorrect│
│     [55%]        │ │     [60%]        │ │or    [80%]       │
│                  │ │                  │ │                  │
└────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
         │                    │                    │
         │                    │                    │ uses
         │                    │                    │
         │                    │           ┌───────┘
         │                    │           │
         │                    ▼           ▼
         │           ┌──────────────────────┐
         │           │                      │
         │           │   OrderedCorners     │
         │           │   (data class)       │
         │           │      [90%]           │
         │           │                      │
         │           └──────────────────────┘
         │
         ▼
┌──────────────────┐
│                  │
│DetectionDebugRes │
│ult (data class)  │
│     [90%]        │
│                  │
└──────────────────┘

                    ┌──────────────────────┐
                    │                      │
                    │   OpenCV Library     │
                    │    (external)        │
                    │      [95%]           │
                    │                      │
                    └──────────────────────┘
                               ▲
                               │
                               │ (only used by RealDetectionService)
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           │                   │                   │
┌──────────┴───────┐ ┌─────────┴────────┐ ┌───────┴──────────┐
│RectangleDetector │ │  CornerOrderer   │ │PerspectiveCorrect│
│                  │ │  (Point class)   │ │or                │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

---

## Design Patterns Used

### 1. Dependency Injection / Interface Segregation

**Files**: `DetectionService.kt`, `RealDetectionService.kt`, `MockDetectionService.kt`
**Confidence**: 95%

```kotlin
interface DetectionService {
    fun detectAndCorrect(bitmap: Bitmap, outputWidth: Int = 512): DetectionResult
    val serviceName: String
}

class RealDetectionService : DetectionService { ... }  // Uses OpenCV
class MockDetectionService : DetectionService { ... }  // Fake results
```

**Rationale**:
- Separates "what" (interface) from "how" (implementation)
- Allows testing Flutter ↔ Native integration without OpenCV
- Enables A/B testing between implementations
- Mock can run without Android SDK installed

---

### 2. Singleton Pattern (Object Declaration)

**File**: `CornerOrderer.kt`
**Confidence**: 90%

```kotlin
object CornerOrderer {
    fun orderCorners(corners: List<Point>): OrderedCorners { ... }
}
```

**Rationale**: Pure function with no state. Singleton ensures single instance and provides namespace for the function.

---

### 3. Data Transfer Objects (DTOs)

**Files**: `CornerOrderer.kt`, `RectangleDetector.kt`
**Confidence**: 90%

```kotlin
data class OrderedCorners(
    val topLeft: Point,
    val topRight: Point,
    val bottomRight: Point,
    val bottomLeft: Point
)

data class DetectionDebugResult(
    val edges: Bitmap,
    val contours: Int,
    val candidates: Int,
    val selected: List<Point>?
)
```

**Rationale**: Immutable data classes for passing structured results between modules. Provides type safety and clear contracts.

---

### 4. Pipeline Pattern

**File**: `MainActivity.kt`
**Confidence**: 85%

```
Input ──► Detect ──► Order ──► Correct ──► Output
```

```kotlin
val corners = detector.detect(bitmap)           // Step 1
val ordered = CornerOrderer.orderCorners(corners)  // Step 2
val corrected = corrector.correct(bitmap, ordered) // Step 3
saveToPng(corrected)                              // Step 4
```

**Rationale**: Each step is independent and testable. Failure at any step stops the pipeline cleanly.

---

### 5. Strategy Pattern (Implicit via Tunable Parameters)

**File**: `RectangleDetector.kt`
**Confidence**: 75%

```kotlin
class RectangleDetector {
    var cannyLow: Double = 50.0
    var cannyHigh: Double = 150.0
    var blurKernelSize: Int = 5
    var approxEpsilon: Double = 0.02
    // ... more parameters
}
```

**Rationale**: Parameters can be adjusted at runtime for different detection "strategies" without changing code. Enables A/B testing and per-image tuning.

---

### 6. Method Channel Pattern (Flutter ↔ Native)

**File**: `MainActivity.kt`
**Confidence**: 95%

```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    .setMethodCallHandler { call, result ->
        when (call.method) {
            "startDetection" -> handleStartDetection(result)
            "dismiss" -> result.success(null)
        }
    }
```

**Rationale**: Standard Flutter pattern for platform-specific code. Async communication with typed responses.

---

### 7. Facade Pattern

**File**: `PerspectiveCorrector.kt`
**Confidence**: 80%

```kotlin
fun correctWithUnorderedCorners(
    source: Bitmap,
    corners: List<Point>,
    outputWidth: Int = 512
): Bitmap {
    val orderedCorners = CornerOrderer.orderCorners(corners)
    return correct(source, orderedCorners, outputWidth)
}
```

**Rationale**: Provides simplified interface that handles corner ordering internally. Caller doesn't need to know about `CornerOrderer`.

---

## File Structure

```
android/app/src/main/kotlin/co/enspyr/watermarking_mobile/
│
├── MainActivity.kt                    [95%]  ◄── Entry point, orchestration
│
└── detection/
    │
    │   ─── INTERFACE ───
    ├── DetectionService.kt            [95%]  ◄── Interface + DetectionResult
    │
    │   ─── IMPLEMENTATIONS ───
    ├── RealDetectionService.kt        [70%]  ◄── Uses OpenCV (production)
    ├── MockDetectionService.kt        [95%]  ◄── Fake results (testing)
    │
    │   ─── CORE MODULES ───
    ├── CornerOrderer.kt               [60%]  ◄── Pure function, no deps
    ├── RectangleDetector.kt           [55%]  ◄── OpenCV detection
    └── PerspectiveCorrector.kt        [80%]  ◄── OpenCV perspective warp


android/app/src/androidTest/kotlin/co/enspyr/watermarking_mobile/detection/
│
├── CornerOrdererTest.kt               17 tests
├── RectangleDetectorTest.kt           18 tests
└── PerspectiveCorrectorTest.kt         9 tests
```

---

## Data Flow Diagram

```
┌─────────────┐
│   Flutter   │
│  (Dart)     │
└──────┬──────┘
       │
       │ "startDetection"
       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Gallery    │────►│   Bitmap    │────►│  Grayscale  │
│  Picker     │     │   (ARGB)    │     │    Mat      │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┘
                    │
                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Gaussian   │────►│   Canny     │────►│   Dilated   │
│   Blur      │     │   Edges     │     │   Edges     │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┘
                    │
                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Find       │────►│  Approx     │────►│  Filter     │
│  Contours   │     │  PolyDP     │     │  Quads      │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┘
                    │
                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Select     │────►│   Order     │────►│ Perspective │
│  Largest    │     │  Corners    │     │  Transform  │
│  [55%]      │     │  [60%]      │     │   [80%]     │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┘
                    │
                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Corrected  │────►│  Save as    │────►│  Return     │
│   Bitmap    │     │   PNG       │     │  File Path  │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │   Flutter   │
                                        │  (Dart)     │
                                        └─────────────┘
```

---

## Confidence Summary

```
┌────────────────────────────────────────────────────────────────────┐
│                     CONFIDENCE LEVELS                               │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   MainActivity.kt          ████████████████████████████████  95%   │
│   OpenCV Library           ████████████████████████████████  95%   │
│   Data Classes             ██████████████████████████████    90%   │
│   Pipeline Pattern         ████████████████████████████      85%   │
│   PerspectiveCorrector     ████████████████████████          80%   │
│   Strategy Pattern         ██████████████████████            75%   │
│   CornerOrderer            ████████████████████              60%   │
│   RectangleDetector        ██████████████████                55%   │
│   OpenCV Parameters        ████████████                      40%   │
│                                                                     │
│   ─────────────────────────────────────────────────────────────    │
│   OVERALL PROJECT          ██████████████████████            70%   │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

---

## Testing Coverage

```
┌─────────────────────────┬─────────┬───────────────────────────────┐
│        Module           │  Tests  │        Coverage Areas          │
├─────────────────────────┼─────────┼───────────────────────────────┤
│ CornerOrderer           │   17    │ Rotation, perspective, edges  │
│ RectangleDetector       │   18    │ Shapes, sizes, parameters     │
│ PerspectiveCorrector    │    9    │ Transform, aspect ratio       │
├─────────────────────────┼─────────┼───────────────────────────────┤
│ TOTAL                   │   44    │                               │
└─────────────────────────┴─────────┴───────────────────────────────┘

⚠️  All tests use synthetic images (programmatically generated)
⚠️  No real-world image testing yet
⚠️  Requires Android device/emulator to run
```
