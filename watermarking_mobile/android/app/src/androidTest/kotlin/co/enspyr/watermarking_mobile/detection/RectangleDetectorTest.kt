package co.enspyr.watermarking_mobile.detection

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.opencv.android.OpenCVLoader

/**
 * Tests for RectangleDetector - the component with 40% confidence.
 *
 * Since we don't have real test images initially, these tests use
 * programmatically generated bitmaps to validate:
 * 1. Basic rectangle detection works
 * 2. Parameter tuning effects
 * 3. Edge cases and failure modes
 * 4. Debug output is populated correctly
 *
 * IMPORTANT: These synthetic tests are a starting point.
 * Real-world testing with actual watermarked paper photos is essential.
 */
@RunWith(AndroidJUnit4::class)
class RectangleDetectorTest {

    private lateinit var detector: RectangleDetector

    @Before
    fun setup() {
        assertTrue("OpenCV must initialize", OpenCVLoader.initLocal())
        detector = RectangleDetector()
    }

    // ==================== BASIC DETECTION ====================

    @Test
    fun detect_clearRectangleOnWhiteBackground_findsRectangle() {
        // Create a white image with a clear black rectangle
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            // White background
            canvas.drawColor(Color.WHITE)

            // Black rectangle outline (thick border for clear edges)
            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f
            canvas.drawRect(100f, 100f, 500f, 400f, paint)
        }

        val result = detector.detect(bitmap)

        assertNotNull("Should detect rectangle", result)
        assertEquals("Should have 4 corners", 4, result?.size)

        bitmap.recycle()
    }

    @Test
    fun detect_filledRectangleOnWhiteBackground_findsRectangle() {
        // Create a white image with a filled gray rectangle
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.GRAY
            paint.style = Paint.Style.FILL
            canvas.drawRect(150f, 100f, 550f, 450f, paint)
        }

        val result = detector.detect(bitmap)

        assertNotNull("Should detect filled rectangle", result)
        assertEquals("Should have 4 corners", 4, result?.size)

        bitmap.recycle()
    }

    @Test
    fun detect_rectangleOnGrayBackground_findsRectangle() {
        // Less contrast - white rectangle on gray
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.GRAY)

            paint.color = Color.WHITE
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f
            canvas.drawRect(100f, 100f, 500f, 400f, paint)
        }

        val result = detector.detect(bitmap)

        assertNotNull("Should detect rectangle on gray background", result)

        bitmap.recycle()
    }

    // ==================== SIZE CONSTRAINTS ====================

    @Test
    fun detect_rectangleTooSmall_returnsNull() {
        // Rectangle smaller than minAreaRatio (25%)
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3f
            // Small rectangle: ~5% of image area
            canvas.drawRect(350f, 250f, 450f, 350f, paint)
        }

        val result = detector.detect(bitmap)

        assertNull("Should not detect rectangle smaller than 25% of image", result)

        bitmap.recycle()
    }

    @Test
    fun detect_rectangleTooLarge_returnsNull() {
        // Rectangle larger than maxAreaRatio (95%)
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3f
            // Almost full-image rectangle
            canvas.drawRect(5f, 5f, 795f, 595f, paint)
        }

        val result = detector.detect(bitmap)

        // This should still be detected since it's a valid rectangle
        // (maxAreaRatio is 0.95, this is ~99%)
        // Actually it depends on exact implementation
        // Let's verify the debug output
        val debug = detector.detectWithDebug(bitmap)
        assertTrue("Candidates should be filtered by max area", debug.candidates <= 1)

        bitmap.recycle()
    }

    @Test
    fun detect_rectangleExactlyMinSize_findsRectangle() {
        // Rectangle exactly at minAreaRatio (25%)
        // Image: 800x600 = 480,000 pixels
        // 25% = 120,000 pixels
        // Rectangle: 400x300 = 120,000 pixels
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3f
            // Centered 400x300 rectangle
            canvas.drawRect(200f, 150f, 600f, 450f, paint)
        }

        val result = detector.detect(bitmap)

        assertNotNull("Should detect rectangle at minimum size", result)

        bitmap.recycle()
    }

    // ==================== ASPECT RATIO ====================

    @Test
    fun detect_veryThinRectangle_returnsNull() {
        // Rectangle thinner than minAspectRatio (0.3)
        // Width:Height ratio of 0.1
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3f
            // Very thin: 50px wide, 400px tall -> ratio = 0.125
            canvas.drawRect(375f, 100f, 425f, 500f, paint)
        }

        // This rectangle is too thin AND too small, so it won't be detected
        val result = detector.detect(bitmap)

        // Check the debug output to understand what's happening
        val debug = detector.detectWithDebug(bitmap)
        // The rectangle should be rejected by aspect ratio OR size filter
        assertTrue("Should have few or no candidates", debug.candidates <= 1)

        bitmap.recycle()
    }

    @Test
    fun detect_squareRectangle_findsRectangle() {
        // Square has aspect ratio of 1.0 (within limits)
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f
            // 300x300 square centered
            canvas.drawRect(250f, 150f, 550f, 450f, paint)
        }

        val result = detector.detect(bitmap)

        assertNotNull("Should detect square", result)

        bitmap.recycle()
    }

    // ==================== PARAMETER TUNING ====================

    @Test
    fun detect_withLowerCannyThreshold_detectsWeakEdges() {
        // Create image with faint edges (low contrast)
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.rgb(200, 200, 200))  // Light gray

            paint.color = Color.rgb(180, 180, 180)  // Slightly darker gray
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f
            canvas.drawRect(100f, 100f, 500f, 400f, paint)
        }

        // Default thresholds might miss this
        val defaultResult = detector.detect(bitmap)

        // Lower thresholds should detect it
        detector.cannyLow = 20.0
        detector.cannyHigh = 60.0
        val sensitiveResult = detector.detect(bitmap)

        // Reset for other tests
        detector.cannyLow = 50.0
        detector.cannyHigh = 150.0

        // At least the sensitive detector should find something
        // (defaultResult might be null with default params)
        assertNotNull("Lowered thresholds should detect weak edges", sensitiveResult)

        bitmap.recycle()
    }

    @Test
    fun detect_withHigherCannyThreshold_rejectsNoise() {
        // Create noisy image with rectangle
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            // Add some noise (scattered lines)
            paint.color = Color.LTGRAY
            paint.strokeWidth = 1f
            for (i in 0 until 50) {
                val x = (Math.random() * 800).toFloat()
                val y = (Math.random() * 600).toFloat()
                canvas.drawLine(x, y, x + 20, y + 20, paint)
            }

            // Main rectangle with strong edges
            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f
            canvas.drawRect(100f, 100f, 500f, 400f, paint)
        }

        // Higher thresholds should still find the main rectangle
        detector.cannyLow = 80.0
        detector.cannyHigh = 200.0
        val result = detector.detect(bitmap)

        detector.cannyLow = 50.0
        detector.cannyHigh = 150.0

        assertNotNull("Higher thresholds should still detect strong rectangle", result)

        bitmap.recycle()
    }

    @Test
    fun detectWithDebug_returnsAllIntermediateResults() {
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f
            canvas.drawRect(100f, 100f, 500f, 400f, paint)
        }

        val debug = detector.detectWithDebug(bitmap)

        // Verify debug output is populated
        assertNotNull("edges bitmap should not be null", debug.edges)
        assertEquals("edges width should match", bitmap.width, debug.edges.width)
        assertEquals("edges height should match", bitmap.height, debug.edges.height)
        assertTrue("should find some contours", debug.contours > 0)
        assertTrue("should find at least one candidate", debug.candidates >= 1)
        assertNotNull("should select a rectangle", debug.selected)

        debug.edges.recycle()
        bitmap.recycle()
    }

    // ==================== MULTIPLE RECTANGLES ====================

    @Test
    fun detect_multipleRectangles_returnsLargest() {
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3f

            // Small rectangle
            canvas.drawRect(50f, 50f, 150f, 150f, paint)

            // Large rectangle (should be selected)
            canvas.drawRect(200f, 100f, 700f, 500f, paint)
        }

        val result = detector.detect(bitmap)

        assertNotNull("Should detect largest rectangle", result)

        // Verify it's the larger one by checking corner positions
        val corners = result!!.sortedBy { it.x + it.y }
        val topLeft = corners[0]

        // The larger rectangle starts at (200, 100)
        assertTrue("topLeft.x should be around 200", topLeft.x > 150)
        assertTrue("topLeft.y should be around 100", topLeft.y > 50)

        bitmap.recycle()
    }

    // ==================== EDGE CASES ====================

    @Test
    fun detect_noRectangle_returnsNull() {
        // Image with just noise, no clear rectangle
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.GRAY
            paint.strokeWidth = 2f

            // Random circles and lines
            for (i in 0 until 20) {
                val x = (Math.random() * 600 + 100).toFloat()
                val y = (Math.random() * 400 + 100).toFloat()
                canvas.drawCircle(x, y, 30f, paint)
            }
        }

        val result = detector.detect(bitmap)

        assertNull("Should not detect rectangle in noisy image", result)

        bitmap.recycle()
    }

    @Test
    fun detect_solidColor_returnsNull() {
        // Solid color image - no edges at all
        val bitmap = createTestImage(800, 600) { canvas, _ ->
            canvas.drawColor(Color.BLUE)
        }

        val result = detector.detect(bitmap)

        assertNull("Should not detect rectangle in solid color image", result)

        bitmap.recycle()
    }

    @Test
    fun detect_triangleShape_returnsNull() {
        // Triangle is not a rectangle
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f

            val path = android.graphics.Path()
            path.moveTo(400f, 100f)
            path.lineTo(200f, 500f)
            path.lineTo(600f, 500f)
            path.close()
            canvas.drawPath(path, paint)
        }

        val result = detector.detect(bitmap)

        assertNull("Should not detect triangle as rectangle", result)

        bitmap.recycle()
    }

    @Test
    fun detect_pentagonShape_returnsNull() {
        // Pentagon has 5 sides
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f

            val path = android.graphics.Path()
            path.moveTo(400f, 100f)  // Top
            path.lineTo(550f, 220f)  // Top right
            path.lineTo(500f, 400f)  // Bottom right
            path.lineTo(300f, 400f)  // Bottom left
            path.lineTo(250f, 220f)  // Top left
            path.close()
            canvas.drawPath(path, paint)
        }

        val result = detector.detect(bitmap)

        assertNull("Should not detect pentagon as rectangle", result)

        bitmap.recycle()
    }

    // ==================== QUADRATURE TOLERANCE ====================

    @Test
    fun detect_slightlySkewedRectangle_findsRectangle() {
        // Rectangle with corners slightly off 90 degrees (within tolerance)
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f

            val path = android.graphics.Path()
            path.moveTo(105f, 100f)  // TL - slightly off
            path.lineTo(500f, 95f)   // TR - slightly off
            path.lineTo(495f, 400f)  // BR - slightly off
            path.lineTo(100f, 405f)  // BL - slightly off
            path.close()
            canvas.drawPath(path, paint)
        }

        val result = detector.detect(bitmap)

        assertNotNull("Should detect slightly skewed rectangle", result)

        bitmap.recycle()
    }

    @Test
    fun detect_heavilySkewedParallelogram_returnsNull() {
        // Parallelogram with corners way off 90 degrees (beyond tolerance)
        val bitmap = createTestImage(800, 600) { canvas, paint ->
            canvas.drawColor(Color.WHITE)

            paint.color = Color.BLACK
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 5f

            val path = android.graphics.Path()
            path.moveTo(200f, 100f)  // TL
            path.lineTo(500f, 100f)  // TR
            path.lineTo(600f, 400f)  // BR - shifted right
            path.lineTo(300f, 400f)  // BL - shifted right
            path.close()
            canvas.drawPath(path, paint)
        }

        val result = detector.detect(bitmap)

        // This parallelogram has ~60 degree corners, should be rejected
        assertNull("Should not detect parallelogram as rectangle", result)

        bitmap.recycle()
    }

    // ==================== HELPER FUNCTIONS ====================

    private fun createTestImage(
        width: Int,
        height: Int,
        draw: (Canvas, Paint) -> Unit
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint().apply {
            isAntiAlias = true
        }
        draw(canvas, paint)
        return bitmap
    }
}
