# Android Rectangle Detection Implementation Plan

## Overview

Translate iOS rectangle detection to Android with **simplified image-only workflow**:
- **Input**: User picks image from gallery (no camera)
- **Detection**: OpenCV for rectangle finding & perspective correction
- **Output**: Corrected image returned to Flutter

**Removed from scope**: Camera, video frames, frame accumulation, OpenGL shaders.

---

## Simplified Flow

```
1. Flutter calls startDetection()
2. Android opens gallery picker
3. User selects image
4. OpenCV detects rectangle, orders corners
5. OpenCV applies perspective correction
6. Corrected image saved as PNG
7. File path returned to Flutter
```

---

## iOS → Android Mapping (Simplified)

| iOS Component | Android Equivalent | Status |
|---------------|-------------------|--------|
| `AppDelegate.swift` (method channel) | `MainActivity.kt` | Needed |
| `RectangleDetector.swift` (Vision) | `RectangleDetector.kt` (OpenCV) | Needed |
| `CIPerspectiveCorrection` | `PerspectiveCorrector.kt` (OpenCV) | Needed |
| ARKit camera | **Gallery picker** | Simplified |
| CIImageAccumulator + Metal | **Not needed** | Removed |

---

## Files to Modify

### 1. `watermarking_mobile/android/app/build.gradle`
```groovy
dependencies {
    // OpenCV 4.9.0
    implementation 'org.opencv:opencv:4.9.0'

    // Coroutines
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'
    implementation 'androidx.activity:activity-ktx:1.8.2'
}
```

### 2. `watermarking_mobile/android/app/src/main/AndroidManifest.xml`
```xml
<!-- No camera permission needed! -->
<activity android:name=".ImagePickerActivity" ... />
```

---

## Files to Create

### Modular Architecture

```
co.enspyr.watermarking_mobile/
├── detection/
│   ├── CornerOrderer.kt        ← Pure function, no dependencies
│   ├── RectangleDetector.kt    ← Takes Bitmap, returns corners
│   └── PerspectiveCorrector.kt ← Takes Bitmap + corners, returns corrected Bitmap
└── ui/
    ├── MainActivity.kt         ← Flutter method channel
    └── DebugActivity.kt        ← Test UI for tuning (optional)
```

### Module Specifications

#### 1. CornerOrderer (Pure function - easiest to test)
```kotlin
object CornerOrderer {
    fun orderCorners(corners: List<Point>): OrderedCorners
    // Returns: topLeft, topRight, bottomRight, bottomLeft
}

data class OrderedCorners(
    val topLeft: Point,
    val topRight: Point,
    val bottomRight: Point,
    val bottomLeft: Point
)
```

#### 2. RectangleDetector (Static image testing)
```kotlin
class RectangleDetector {
    // Tunable parameters
    var cannyLow: Double = 50.0
    var cannyHigh: Double = 150.0
    var approxEpsilon: Double = 0.02
    var minAreaRatio: Double = 0.25

    fun detect(bitmap: Bitmap): List<Point>?
    fun detectWithDebug(bitmap: Bitmap): DetectionDebugResult
}

data class DetectionDebugResult(
    val edges: Bitmap,
    val contours: List<MatOfPoint>,
    val candidates: List<MatOfPoint2f>,
    val selected: List<Point>?
)
```

#### 3. PerspectiveCorrector
```kotlin
class PerspectiveCorrector {
    fun correct(source: Bitmap, corners: OrderedCorners, outputWidth: Int = 512): Bitmap
}
```

#### 4. MainActivity (Method Channel)
```kotlin
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "watermarking.enspyr.co/detect"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(...).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDetection" -> openGalleryPicker(result)
                "dismiss" -> result.success(null)
            }
        }
    }

    private fun openGalleryPicker(result: MethodChannel.Result) {
        // Launch image picker
        // On image selected: detect → correct → save → return path
    }
}
```

---

## Implementation Order

**Phase 1: Core modules (3 files)**
1. `build.gradle` - Add OpenCV dependency
2. `CornerOrderer.kt` - Pure function + unit tests
3. `RectangleDetector.kt` - OpenCV detection + unit tests
4. `PerspectiveCorrector.kt` - OpenCV warp + unit tests

**Phase 2: Integration (2 files)**
5. `MainActivity.kt` - Gallery picker + method channel
6. `AndroidManifest.xml` - Activity declaration

**Phase 3: Testing**
7. Unit tests with static images
8. End-to-end test with Flutter

---

## Risks & Confidence (Updated)

With gallery picker, we've **eliminated**:
- ~~OpenGL ES Pbuffer compatibility~~ (removed)
- ~~YUV to RGB conversion~~ (removed)
- ~~Performance on mid-range devices~~ (single image, not real-time)
- ~~Camera frame quality~~ (removed)

**Remaining risks:**

| Area | Confidence | Notes |
|------|------------|-------|
| Corner ordering | **60%** | Still tricky with perspective distortion |
| OpenCV parameters | **40%** | Will need tuning on real images |
| OpenCV initialization | **90%** | Well-documented, should work |
| Gallery picker | **95%** | Standard Android API |

---

## Areas of Least Confidence (Detailed)

### 1. Corner Ordering Algorithm (HIGHEST UNCERTAINTY)

**The problem**: Labeling 4 detected corners as top-left, top-right, bottom-right, bottom-left with perspective distortion.

**Why it's hard**:
- "Top-left" may be physically lower than "top-right" when angled
- Simple `sort by x+y` heuristic fails when tilted >45°
- iOS Vision returns pre-ordered corners; OpenCV does not

**What could go wrong**:
- Swapped corners = mirrored or rotated output
- User would need to re-select image

**Proposed solution**: Sort by sum (x+y) and difference (y-x).

---

### 2. OpenCV Detection Parameters (HIGH UNCERTAINTY)

**Magic numbers that need tuning**:
| Parameter | Value | Purpose |
|-----------|-------|---------|
| Canny thresholds | `(50, 150)` | Edge sensitivity |
| GaussianBlur kernel | `5x5` | Noise reduction |
| approxPolyDP epsilon | `0.02 * perimeter` | Polygon simplification |
| Minimum area | `0.25` | Rectangle must be 25% of image |

**What could go wrong**:
- Too sensitive → detects table edges, shadows
- Too strict → misses the watermarked paper

**Reality**: Will need adjustment based on real-world testing.

---

## Honest Confidence Assessment

| Area | Confidence | Reality |
|------|------------|---------|
| Corner ordering | **60%** | Will need 2-3 iterations |
| OpenCV parameters | **40%** | Pure guesswork, expect tuning |
| Gallery picker integration | **95%** | Standard Android |
| Overall success | **75%** | Much simpler than camera version |

**Bottom line**:
- This is **dramatically simpler** than the camera version
- Main risks are corner ordering and parameter tuning
- Should be achievable in 1-2 days instead of 4 weeks

---

## Feature Detection & Projection: Detailed Confidence Analysis

### 1. RectangleDetector (Feature Detection)

| Aspect | Confidence | Notes |
|--------|------------|-------|
| OpenCV API usage | **85%** | Standard pipeline, well-documented |
| Canny edge detection | **70%** | Parameters (50, 150) are guesses |
| Contour finding | **80%** | `RETR_EXTERNAL` + `CHAIN_APPROX_SIMPLE` correct |
| Polygon approximation | **60%** | `epsilon = 0.02 * perimeter` copied from tutorials |
| Quadrature tolerance check | **50%** | Angle calculation might have bugs |

**Potential bug in angle calculation** (`checkQuadratureTolerance`):
```kotlin
// Current code iterates through consecutive points:
for (i in 0 until 4) {
    val p1 = points[i]
    val p2 = points[(i + 1) % 4]
    val p3 = points[(i + 2) % 4]
    val angle = calculateAngle(p1, p2, p3)  // Angle at p2
}
```

**Problem**: Checking angle at `p2` with points `p1 → p2 → p3`, but iterating through **consecutive** triplets may not correctly check **corner** angles. The indexing might be calculating edge-to-edge angles rather than corner angles.

---

### 2. PerspectiveCorrector (Projection)

| Aspect | Confidence | Notes |
|--------|------------|-------|
| `getPerspectiveTransform` | **95%** | Correct OpenCV function |
| `warpPerspective` | **95%** | Standard usage |
| Point ordering dependency | **90%** | Relies on CornerOrderer being correct |
| Aspect ratio calculation | **75%** | Uses `maxOf()` not average - may distort |
| Memory management | **85%** | Releasing Mats correctly |

**Potential issue with aspect ratio**:
```kotlin
val srcWidth = corners.width()   // Uses maxOf(top, bottom edge)
val srcHeight = corners.height() // Uses maxOf(left, right edge)
```

For heavily skewed trapezoids, using `maxOf` takes the *longest* edges, which may not represent the true aspect ratio and could produce distorted output.

---

### 3. CornerOrderer

| Aspect | Confidence | Notes |
|--------|------------|-------|
| Sum/difference algorithm | **60%** | Works for mild angles, fails at 45°+ |
| Edge case handling | **70%** | Throws on wrong point count |
| Distance calculations | **90%** | Simple Euclidean, correct |

**Known failure case**:
```
45-degree diamond rotation:
- Two points have same sum (x+y)
- Two points have same difference (y-x)
- Result is ambiguous/undefined
```

---

### Overall Component Confidence

| Component | Confidence | Main Risk |
|-----------|------------|-----------|
| RectangleDetector | **55%** | Angle calculation bug, parameter guessing |
| PerspectiveCorrector | **80%** | Aspect ratio distortion on heavy skew |
| CornerOrderer | **60%** | Fails on rotation >45° |

---

### Real-World Image Concerns

All testing assumptions are based on synthetic images. Real photos have:
- Shadows near paper edges
- Reflections on glossy paper
- Partial occlusions (fingers, objects)
- Non-uniform lighting (indoor vs outdoor)
- Camera lens distortion (barrel/pincushion)
- Motion blur if hand-held
- JPEG compression artifacts

**Recommendation**: Test with 10+ real photos before considering implementation complete.

---

## Testing Strategy

### Test with Static Images

1. Export sample images from iOS app (various angles, lighting)
2. Store in `android/app/src/androidTest/assets/test_images/`
3. Unit test each module:

```kotlin
@Test
fun testRectangleDetection() {
    val bitmap = loadTestAsset("watermarked_paper.png")
    val corners = RectangleDetector().detect(bitmap)
    assertNotNull(corners)
    assertEquals(4, corners.size)
}

@Test
fun testCornerOrdering() {
    val unordered = listOf(Point(100, 50), Point(400, 60), Point(90, 300), Point(410, 310))
    val ordered = CornerOrderer.orderCorners(unordered)
    assertEquals(Point(90, 300), ordered.bottomLeft)
}

@Test
fun testPerspectiveCorrection() {
    val bitmap = loadTestAsset("skewed_rectangle.png")
    val corners = OrderedCorners(...)
    val corrected = PerspectiveCorrector().correct(bitmap, corners)
    // Visual inspection or PSNR comparison
}
```

### DebugActivity (Optional)

For manual parameter tuning:
```kotlin
class DebugActivity : AppCompatActivity() {
    // - Load test images
    // - Sliders for Canny thresholds, epsilon
    // - Toggle overlays: edges, contours, corners
    // - Instant visual feedback
}
```

---

## What We Removed (vs Original Plan)

| Component | Original | Now |
|-----------|----------|-----|
| CameraX | Live video feed | Gallery picker |
| YuvConverter | YUV→RGB conversion | Not needed |
| ImageAccumulator | OpenGL frame blending | Not needed |
| OpenGL ES shaders | GPU-accelerated | Not needed |
| 10 FPS processing | Real-time | Single image |
| ARKit equivalent | CameraX + frame analysis | Not needed |

**Complexity reduction**: ~70% less code, ~90% less risk.
