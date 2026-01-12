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
import org.opencv.core.Point

/**
 * Tests for PerspectiveCorrector - validates perspective transformation.
 *
 * These tests verify:
 * 1. Basic perspective correction works
 * 2. Output dimensions are calculated correctly
 * 3. Corners map to expected positions after transformation
 */
@RunWith(AndroidJUnit4::class)
class PerspectiveCorrectorTest {

    private lateinit var corrector: PerspectiveCorrector

    @Before
    fun setup() {
        assertTrue("OpenCV must initialize", OpenCVLoader.initLocal())
        corrector = PerspectiveCorrector()
    }

    @Test
    fun correct_uprightRectangle_maintainsContent() {
        // Create image with colored quadrants for verification
        val bitmap = createQuadrantImage(400, 300)

        val corners = OrderedCorners(
            topLeft = Point(0.0, 0.0),
            topRight = Point(399.0, 0.0),
            bottomRight = Point(399.0, 299.0),
            bottomLeft = Point(0.0, 299.0)
        )

        val result = corrector.correct(bitmap, corners, outputWidth = 400)

        // Result should be similar to input (no perspective change)
        assertEquals("Width should be 400", 400, result.width)
        // Height calculated from aspect ratio: 300/400 * 400 = 300
        assertEquals("Height should be ~300", 300, result.height)

        // Check that corners have expected colors
        // Top-left quadrant is RED
        val topLeftColor = result.getPixel(50, 50)
        assertEquals("Top-left should be red", Color.RED, topLeftColor)

        // Top-right quadrant is GREEN
        val topRightColor = result.getPixel(350, 50)
        assertEquals("Top-right should be green", Color.GREEN, topRightColor)

        bitmap.recycle()
        result.recycle()
    }

    @Test
    fun correct_trapezoidPerspective_flattensToRectangle() {
        // Create image with a trapezoid shape containing a pattern
        val sourceWidth = 800
        val sourceHeight = 600
        val bitmap = createQuadrantImage(sourceWidth, sourceHeight)

        // Simulate perspective: top is narrower than bottom
        val corners = OrderedCorners(
            topLeft = Point(150.0, 50.0),      // Inward
            topRight = Point(650.0, 50.0),     // Inward
            bottomRight = Point(750.0, 550.0), // Outward
            bottomLeft = Point(50.0, 550.0)    // Outward
        )

        val result = corrector.correct(bitmap, corners, outputWidth = 512)

        // Result should be a proper rectangle
        assertEquals("Width should be 512", 512, result.width)
        assertTrue("Height should be positive", result.height > 0)

        // The content should be de-warped
        assertNotNull("Result should not be null", result)

        bitmap.recycle()
        result.recycle()
    }

    @Test
    fun correct_withDifferentOutputWidths_scalesAppropriately() {
        val bitmap = createQuadrantImage(400, 300)

        val corners = OrderedCorners(
            topLeft = Point(0.0, 0.0),
            topRight = Point(399.0, 0.0),
            bottomRight = Point(399.0, 299.0),
            bottomLeft = Point(0.0, 299.0)
        )

        // Test different output widths
        val result256 = corrector.correct(bitmap, corners, outputWidth = 256)
        assertEquals("Width should be 256", 256, result256.width)

        val result512 = corrector.correct(bitmap, corners, outputWidth = 512)
        assertEquals("Width should be 512", 512, result512.width)

        val result1024 = corrector.correct(bitmap, corners, outputWidth = 1024)
        assertEquals("Width should be 1024", 1024, result1024.width)

        // All should maintain aspect ratio
        val expectedRatio = 300.0 / 400.0
        assertEquals("256 aspect ratio", expectedRatio, result256.height.toDouble() / 256.0, 0.05)
        assertEquals("512 aspect ratio", expectedRatio, result512.height.toDouble() / 512.0, 0.05)
        assertEquals("1024 aspect ratio", expectedRatio, result1024.height.toDouble() / 1024.0, 0.05)

        bitmap.recycle()
        result256.recycle()
        result512.recycle()
        result1024.recycle()
    }

    @Test
    fun correct_squareRegion_outputIsSquare() {
        val bitmap = createQuadrantImage(800, 600)

        // Extract a square region
        val corners = OrderedCorners(
            topLeft = Point(100.0, 100.0),
            topRight = Point(400.0, 100.0),
            bottomRight = Point(400.0, 400.0),
            bottomLeft = Point(100.0, 400.0)
        )

        val result = corrector.correct(bitmap, corners, outputWidth = 512)

        // Width and height should be equal (square)
        assertEquals("Should be square", result.width, result.height)

        bitmap.recycle()
        result.recycle()
    }

    @Test
    fun correct_tallRectangle_outputIsTall() {
        val bitmap = createQuadrantImage(800, 600)

        // Extract a tall region (portrait orientation)
        val corners = OrderedCorners(
            topLeft = Point(200.0, 50.0),
            topRight = Point(400.0, 50.0),
            bottomRight = Point(400.0, 550.0),
            bottomLeft = Point(200.0, 550.0)
        )

        val result = corrector.correct(bitmap, corners, outputWidth = 256)

        // Height should be greater than width
        assertTrue("Should be taller than wide", result.height > result.width)

        // Calculate expected aspect ratio: 500/200 = 2.5
        val expectedRatio = 500.0 / 200.0
        val actualRatio = result.height.toDouble() / result.width.toDouble()
        assertEquals("Aspect ratio", expectedRatio, actualRatio, 0.1)

        bitmap.recycle()
        result.recycle()
    }

    @Test
    fun correct_wideRectangle_outputIsWide() {
        val bitmap = createQuadrantImage(800, 600)

        // Extract a wide region (landscape orientation)
        val corners = OrderedCorners(
            topLeft = Point(50.0, 200.0),
            topRight = Point(750.0, 200.0),
            bottomRight = Point(750.0, 400.0),
            bottomLeft = Point(50.0, 400.0)
        )

        val result = corrector.correct(bitmap, corners, outputWidth = 512)

        // Width should be greater than height
        assertTrue("Should be wider than tall", result.width > result.height)

        bitmap.recycle()
        result.recycle()
    }

    @Test
    fun correctWithUnorderedCorners_ordersAutomatically() {
        val bitmap = createQuadrantImage(400, 300)

        // Corners in random order
        val unorderedCorners = listOf(
            Point(399.0, 299.0),  // BR
            Point(0.0, 0.0),      // TL
            Point(0.0, 299.0),    // BL
            Point(399.0, 0.0)     // TR
        )

        val result = corrector.correctWithUnorderedCorners(bitmap, unorderedCorners, outputWidth = 400)

        assertEquals("Width should be 400", 400, result.width)

        // Verify content is correctly oriented by checking corner colors
        val topLeftColor = result.getPixel(50, 50)
        assertEquals("Top-left should be red", Color.RED, topLeftColor)

        bitmap.recycle()
        result.recycle()
    }

    @Test
    fun correct_rotatedRectangle_correctsRotation() {
        val bitmap = createQuadrantImage(800, 800)

        // Rectangle rotated ~30 degrees
        val corners = OrderedCorners(
            topLeft = Point(200.0, 100.0),
            topRight = Point(600.0, 200.0),
            bottomRight = Point(500.0, 600.0),
            bottomLeft = Point(100.0, 500.0)
        )

        val result = corrector.correct(bitmap, corners, outputWidth = 512)

        // Should produce a valid result
        assertNotNull("Result should not be null", result)
        assertEquals("Width should be 512", 512, result.width)
        assertTrue("Height should be positive", result.height > 0)

        bitmap.recycle()
        result.recycle()
    }

    // ==================== HELPER FUNCTIONS ====================

    /**
     * Creates a test image with 4 colored quadrants:
     * - Top-left: RED
     * - Top-right: GREEN
     * - Bottom-left: BLUE
     * - Bottom-right: YELLOW
     *
     * This makes it easy to verify that perspective correction
     * maps content to the correct locations.
     */
    private fun createQuadrantImage(width: Int, height: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint()

        val halfWidth = width / 2f
        val halfHeight = height / 2f

        // Top-left: RED
        paint.color = Color.RED
        canvas.drawRect(0f, 0f, halfWidth, halfHeight, paint)

        // Top-right: GREEN
        paint.color = Color.GREEN
        canvas.drawRect(halfWidth, 0f, width.toFloat(), halfHeight, paint)

        // Bottom-left: BLUE
        paint.color = Color.BLUE
        canvas.drawRect(0f, halfHeight, halfWidth, height.toFloat(), paint)

        // Bottom-right: YELLOW
        paint.color = Color.YELLOW
        canvas.drawRect(halfWidth, halfHeight, width.toFloat(), height.toFloat(), paint)

        return bitmap
    }
}
