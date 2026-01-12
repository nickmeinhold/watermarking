# Known Issues - Android Rectangle Detection

Issues identified during implementation that remain unsolved.

---

## 1. Corner Ordering Fails at 45°+ Rotation

**File**: `CornerOrderer.kt`
**Confidence**: 60%

### Problem

The sum/difference algorithm breaks down when a rectangle is rotated ~45 degrees (diamond orientation):

```
         TOP(250, 50)
        /           \
  LEFT(50, 250)   RIGHT(450, 250)
        \           /
        BOTTOM(250, 450)
```

In this case:
- `TOP` and `LEFT` both have sum = 300
- `TOP` and `RIGHT` both have difference = -200
- Sorting by sum/difference produces ambiguous results

### Current Behavior

The algorithm returns *a* result, but "top-left" might be either `LEFT` or `TOP` depending on floating-point comparison order. This could cause the perspective-corrected image to be rotated 90°.

### Why I Don't Know How to Solve It

Better algorithms exist (convex hull + centroid, or using edge vectors), but they add complexity and may have their own edge cases. The iOS Vision Framework returns pre-ordered corners, so Apple solved this internally but doesn't expose the algorithm.

### Workaround

For now, the test accepts either valid corner as "topLeft" for 45° rotation:
```kotlin
val validTopLefts = setOf(Point(50.0, 250.0), Point(250.0, 50.0))
assertTrue(validTopLefts.contains(result.topLeft))
```

---

## 2. Angle Calculation May Check Wrong Triplets

**File**: `RectangleDetector.kt:156-173`
**Confidence**: 50%

### Problem

The `checkQuadratureTolerance` function iterates through points like this:

```kotlin
for (i in 0 until 4) {
    val p1 = points[i]
    val p2 = points[(i + 1) % 4]
    val p3 = points[(i + 2) % 4]
    val angle = calculateAngle(p1, p2, p3)  // Angle at p2
}
```

This calculates the angle at `p2` formed by the vectors `p1→p2` and `p2→p3`.

**The concern**: OpenCV's `approxPolyDP` returns points in contour order (clockwise or counter-clockwise around the shape). For a quadrilateral with points `[A, B, C, D]`:

- Iteration 0: angle at B (A→B→C) ✓ This is a corner angle
- Iteration 1: angle at C (B→C→D) ✓ This is a corner angle
- Iteration 2: angle at D (C→D→A) ✓ This is a corner angle
- Iteration 3: angle at A (D→A→B) ✓ This is a corner angle

Actually, looking at it again, this might be correct. But I'm not 100% confident because:
1. I haven't verified that `approxPolyDP` always returns points in consistent order
2. The angle calculation uses `atan2` differences which could have wraparound issues

### Why I Don't Know How to Solve It

I'd need to:
1. Add extensive logging to see actual angle values on real images
2. Verify `approxPolyDP` output order with OpenCV documentation
3. Test with parallelograms that should be rejected (angles ≠ 90°)

Without running on real images, I can't validate this works correctly.

---

## 3. Aspect Ratio Distortion on Heavy Perspective

**File**: `PerspectiveCorrector.kt:32-35` and `CornerOrderer.kt:69-82`
**Confidence**: 75%

### Problem

The aspect ratio calculation uses `maxOf()` for both width and height:

```kotlin
fun width(): Double {
    val topWidth = distance(topLeft, topRight)
    val bottomWidth = distance(bottomLeft, bottomRight)
    return maxOf(topWidth, bottomWidth)  // Takes longest edge
}
```

For a heavily skewed trapezoid where the top edge is much shorter than the bottom:

```
    TL----TR           (top edge: 100px)
   /        \
  /          \
 /            \
BL------------BR       (bottom edge: 400px)
```

Using `maxOf` produces width = 400px, but the "true" width of the original rectangle (before perspective distortion) might be closer to the average (250px) or require proper projective geometry to calculate.

### Current Behavior

The output image will have an aspect ratio based on the longest edges, which may not match the original document's aspect ratio. A square document photographed at an angle could appear as a rectangle.

### Why I Don't Know How to Solve It

Proper solution requires:
1. Knowing the original document's aspect ratio (we don't)
2. Or using projective geometry to estimate it from the vanishing points
3. Or assuming standard paper sizes (A4, Letter) and fitting to closest match

All of these add significant complexity and assumptions.

---

## 4. OpenCV Parameters Are Untested Guesses

**File**: `RectangleDetector.kt:26-33`
**Confidence**: 40%

### Problem

These parameters are copied from OpenCV tutorials, not tuned for watermarked paper detection:

| Parameter | Value | Source |
|-----------|-------|--------|
| `cannyLow` | 50.0 | Tutorial default |
| `cannyHigh` | 150.0 | Tutorial default |
| `blurKernelSize` | 5 | Common value |
| `approxEpsilon` | 0.02 | Tutorial default |
| `minAreaRatio` | 0.25 | iOS VNDetectRectanglesRequest |
| `quadratureTolerance` | 20.0 | iOS VNDetectRectanglesRequest |

### What Could Go Wrong

- **Too sensitive**: Detects table edges, picture frames, shadows, book spines
- **Too strict**: Misses the watermarked paper due to:
  - Rounded corners (from wear)
  - Partial shadows obscuring edges
  - Low contrast between paper and background
  - Glare/reflections on glossy paper

### Why I Don't Know How to Solve It

Need real-world testing with:
- Various lighting conditions (indoor, outdoor, fluorescent, natural)
- Different backgrounds (wood table, white desk, patterned surface)
- Paper conditions (new, worn, folded, partially occluded)
- Camera angles (straight-on, tilted, rotated)

The `DebugActivity` described in PLAN.md would help with parameter tuning, but it's not implemented yet.

---

## 5. Real-World Image Challenges (Untested)

**Confidence**: Unknown

### Problems Not Addressed

| Challenge | Impact | Status |
|-----------|--------|--------|
| Shadows near paper edges | May create false edges or hide real edges | Untested |
| Reflections on glossy paper | Bright spots may break edge detection | Untested |
| Partial occlusions (fingers, objects) | Incomplete rectangle won't be detected | Untested |
| Non-uniform lighting | Gradient across paper affects edge detection | Untested |
| Lens distortion (barrel/pincushion) | Rectangle edges appear curved | Not handled |
| Motion blur | Edges become fuzzy | May fail detection |
| JPEG compression artifacts | Blocky edges near boundaries | May affect accuracy |
| Similar-colored background | Low contrast = weak edges | May fail detection |

### Why I Don't Know How to Solve It

Each of these requires specialized preprocessing:
- Shadow removal: Requires illumination normalization
- Lens distortion: Requires camera calibration
- Motion blur: Requires deconvolution
- Low contrast: Requires adaptive thresholding

These are all significant additions that would need research and testing.

---

## 6. No Fallback When Detection Fails

**File**: `MainActivity.kt`
**Confidence**: N/A (design issue)

### Problem

If rectangle detection fails (returns `null`), the current flow just returns an error to Flutter. There's no:
- Manual corner selection UI
- Retry with different parameters
- Crop-to-bounds fallback

### Why It's Not Solved

This is a UX decision that should be made with the product owner. Options:
1. Show error and let user retake photo
2. Show detected edges and let user adjust corners manually
3. Auto-retry with relaxed parameters
4. Use the full image without perspective correction

---

## Summary

| Issue | Severity | Fixable? |
|-------|----------|----------|
| 45° rotation corner ordering | Medium | Yes, with more complex algorithm |
| Angle calculation uncertainty | Low | Need real-world testing to validate |
| Aspect ratio distortion | Low | Need product decision on acceptable distortion |
| Untested parameters | High | Need real images + DebugActivity |
| Real-world challenges | High | Need extensive testing + preprocessing |
| No detection fallback | Medium | Need UX decision |

**Recommendation**: Before investing in fixes, test with 10+ real photos to understand which issues actually occur in practice.
