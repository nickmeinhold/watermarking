package co.enspyr.watermarking_mobile.detection

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.opencv.android.OpenCVLoader
import org.opencv.core.Point

/**
 * Tests for CornerOrderer - the highest uncertainty component.
 *
 * Tests cover:
 * 1. Basic ordering with upright rectangle
 * 2. Mild perspective distortion (common case)
 * 3. Rotated rectangle (45 degrees)
 * 4. Extreme perspective (looking from steep angle)
 * 5. Edge cases (very thin rectangles, squares)
 * 6. Invalid inputs
 *
 * These tests help validate the "sort by sum/difference" algorithm
 * that I'm only 60% confident about.
 */
@RunWith(AndroidJUnit4::class)
class CornerOrdererTest {

    @Before
    fun setup() {
        // Initialize OpenCV
        assertTrue("OpenCV must initialize", OpenCVLoader.initLocal())
    }

    // ==================== BASIC CASES ====================

    @Test
    fun orderCorners_uprightRectangle_correctOrder() {
        // Simple upright rectangle - the easiest case
        // TL(100,100) -- TR(400,100)
        //     |              |
        // BL(100,300) -- BR(400,300)
        val corners = listOf(
            Point(400.0, 300.0),  // BR - given out of order
            Point(100.0, 100.0),  // TL
            Point(400.0, 100.0),  // TR
            Point(100.0, 300.0)   // BL
        )

        val result = CornerOrderer.orderCorners(corners)

        assertEquals("topLeft.x", 100.0, result.topLeft.x, 0.01)
        assertEquals("topLeft.y", 100.0, result.topLeft.y, 0.01)
        assertEquals("topRight.x", 400.0, result.topRight.x, 0.01)
        assertEquals("topRight.y", 100.0, result.topRight.y, 0.01)
        assertEquals("bottomRight.x", 400.0, result.bottomRight.x, 0.01)
        assertEquals("bottomRight.y", 300.0, result.bottomRight.y, 0.01)
        assertEquals("bottomLeft.x", 100.0, result.bottomLeft.x, 0.01)
        assertEquals("bottomLeft.y", 300.0, result.bottomLeft.y, 0.01)
    }

    @Test
    fun orderCorners_squareRectangle_correctOrder() {
        // Square - aspect ratio edge case
        val corners = listOf(
            Point(200.0, 200.0),  // BR
            Point(100.0, 100.0),  // TL
            Point(200.0, 100.0),  // TR
            Point(100.0, 200.0)   // BL
        )

        val result = CornerOrderer.orderCorners(corners)

        assertEquals("topLeft", Point(100.0, 100.0), result.topLeft)
        assertEquals("topRight", Point(200.0, 100.0), result.topRight)
        assertEquals("bottomRight", Point(200.0, 200.0), result.bottomRight)
        assertEquals("bottomLeft", Point(100.0, 200.0), result.bottomLeft)
    }

    // ==================== PERSPECTIVE DISTORTION ====================

    @Test
    fun orderCorners_mildPerspective_correctOrder() {
        // Mild perspective - looking slightly from above
        // Top edge is slightly narrower than bottom (common phone photo)
        // TL(120,100) ---- TR(380,110)
        //     \              /
        // BL(100,300) -- BR(400,290)
        val corners = listOf(
            Point(400.0, 290.0),  // BR
            Point(120.0, 100.0),  // TL
            Point(380.0, 110.0),  // TR
            Point(100.0, 300.0)   // BL
        )

        val result = CornerOrderer.orderCorners(corners)

        // TL should have smallest sum (120+100=220)
        assertEquals("topLeft", Point(120.0, 100.0), result.topLeft)
        // TR should have smallest difference (110-380=-270)
        assertEquals("topRight", Point(380.0, 110.0), result.topRight)
        // BR should have largest sum (400+290=690)
        assertEquals("bottomRight", Point(400.0, 290.0), result.bottomRight)
        // BL should have largest difference (300-100=200)
        assertEquals("bottomLeft", Point(100.0, 300.0), result.bottomLeft)
    }

    @Test
    fun orderCorners_trapezoidPerspective_correctOrder() {
        // Strong trapezoid - looking from an angle
        // Top edge much narrower than bottom
        //    TL(200,50) -- TR(300,60)
        //      /              \
        // BL(50,400) -------- BR(450,380)
        val corners = listOf(
            Point(450.0, 380.0),  // BR
            Point(200.0, 50.0),   // TL
            Point(300.0, 60.0),   // TR
            Point(50.0, 400.0)    // BL
        )

        val result = CornerOrderer.orderCorners(corners)

        assertEquals("topLeft", Point(200.0, 50.0), result.topLeft)
        assertEquals("topRight", Point(300.0, 60.0), result.topRight)
        assertEquals("bottomRight", Point(450.0, 380.0), result.bottomRight)
        assertEquals("bottomLeft", Point(50.0, 400.0), result.bottomLeft)
    }

    // ==================== ROTATION CASES (THE HARD ONES) ====================

    @Test
    fun orderCorners_rotated30Degrees_correctOrder() {
        // Rectangle rotated ~30 degrees clockwise
        // This is where the algorithm might struggle
        //
        //         TR(350, 50)
        //        /          \
        //   TL(100, 150)     BR(450, 250)
        //        \          /
        //         BL(200, 350)
        val corners = listOf(
            Point(450.0, 250.0),  // BR
            Point(100.0, 150.0),  // TL
            Point(350.0, 50.0),   // TR
            Point(200.0, 350.0)   // BL
        )

        val result = CornerOrderer.orderCorners(corners)

        // With 30-degree rotation, the sum/diff algorithm should still work
        // TL(100,150): sum=250, diff=50
        // TR(350,50): sum=400, diff=-300 (smallest diff)
        // BR(450,250): sum=700 (largest sum)
        // BL(200,350): sum=550, diff=150 (largest diff)

        assertEquals("topLeft", Point(100.0, 150.0), result.topLeft)
        assertEquals("topRight", Point(350.0, 50.0), result.topRight)
        assertEquals("bottomRight", Point(450.0, 250.0), result.bottomRight)
        assertEquals("bottomLeft", Point(200.0, 350.0), result.bottomLeft)
    }

    @Test
    fun orderCorners_rotated45Degrees_correctOrder() {
        // Rectangle rotated exactly 45 degrees - diamond shape
        // This is a critical edge case!
        //
        //          TOP(250, 50)
        //         /           \
        //   LEFT(50, 250)   RIGHT(450, 250)
        //         \           /
        //         BOTTOM(250, 450)
        //
        // In this case, "top-left" is ambiguous!
        // The algorithm should pick LEFT as topLeft (smallest sum = 300)
        // and TOP as topRight (smallest diff = -200)
        val corners = listOf(
            Point(250.0, 450.0),  // BOTTOM
            Point(50.0, 250.0),   // LEFT
            Point(250.0, 50.0),   // TOP
            Point(450.0, 250.0)   // RIGHT
        )

        val result = CornerOrderer.orderCorners(corners)

        // TOP(250,50): sum=300, diff=-200 (smallest diff -> topRight)
        // LEFT(50,250): sum=300, diff=200
        // RIGHT(450,250): sum=700, diff=-200
        // BOTTOM(250,450): sum=700, diff=200 (largest diff -> bottomLeft)

        // This is where the algorithm might fail - two points have same sum!
        // Let's see what we get and document the behavior
        assertNotNull("Should return a result", result)

        // For 45-degree rotation, we accept that "topLeft" might be
        // either LEFT or TOP depending on floating point comparison
        val validTopLefts = setOf(Point(50.0, 250.0), Point(250.0, 50.0))
        assertTrue(
            "topLeft should be LEFT or TOP for 45-degree rotation",
            validTopLefts.contains(result.topLeft)
        )
    }

    // ==================== EXTREME CASES ====================

    @Test
    fun orderCorners_veryThinHorizontal_correctOrder() {
        // Very thin horizontal rectangle (aspect ratio ~0.1)
        val corners = listOf(
            Point(500.0, 110.0),  // BR
            Point(100.0, 100.0),  // TL
            Point(500.0, 100.0),  // TR
            Point(100.0, 110.0)   // BL
        )

        val result = CornerOrderer.orderCorners(corners)

        assertEquals("topLeft", Point(100.0, 100.0), result.topLeft)
        assertEquals("topRight", Point(500.0, 100.0), result.topRight)
        assertEquals("bottomRight", Point(500.0, 110.0), result.bottomRight)
        assertEquals("bottomLeft", Point(100.0, 110.0), result.bottomLeft)
    }

    @Test
    fun orderCorners_veryThinVertical_correctOrder() {
        // Very thin vertical rectangle
        val corners = listOf(
            Point(110.0, 500.0),  // BR
            Point(100.0, 100.0),  // TL
            Point(110.0, 100.0),  // TR
            Point(100.0, 500.0)   // BL
        )

        val result = CornerOrderer.orderCorners(corners)

        assertEquals("topLeft", Point(100.0, 100.0), result.topLeft)
        assertEquals("topRight", Point(110.0, 100.0), result.topRight)
        assertEquals("bottomRight", Point(110.0, 500.0), result.bottomRight)
        assertEquals("bottomLeft", Point(100.0, 500.0), result.bottomLeft)
    }

    @Test
    fun orderCorners_nearOrigin_correctOrder() {
        // Rectangle near origin (0,0)
        val corners = listOf(
            Point(20.0, 20.0),  // BR
            Point(0.0, 0.0),    // TL
            Point(20.0, 0.0),   // TR
            Point(0.0, 20.0)    // BL
        )

        val result = CornerOrderer.orderCorners(corners)

        assertEquals("topLeft", Point(0.0, 0.0), result.topLeft)
        assertEquals("topRight", Point(20.0, 0.0), result.topRight)
    }

    @Test
    fun orderCorners_largeCoordinates_correctOrder() {
        // Very large coordinates (like high-res image)
        val corners = listOf(
            Point(4000.0, 3000.0),
            Point(1000.0, 1000.0),
            Point(4000.0, 1000.0),
            Point(1000.0, 3000.0)
        )

        val result = CornerOrderer.orderCorners(corners)

        assertEquals("topLeft", Point(1000.0, 1000.0), result.topLeft)
        assertEquals("bottomRight", Point(4000.0, 3000.0), result.bottomRight)
    }

    // ==================== ERROR CASES ====================

    @Test(expected = IllegalArgumentException::class)
    fun orderCorners_threePoints_throwsException() {
        val corners = listOf(
            Point(100.0, 100.0),
            Point(200.0, 100.0),
            Point(200.0, 200.0)
        )
        CornerOrderer.orderCorners(corners)
    }

    @Test(expected = IllegalArgumentException::class)
    fun orderCorners_fivePoints_throwsException() {
        val corners = listOf(
            Point(100.0, 100.0),
            Point(200.0, 100.0),
            Point(200.0, 200.0),
            Point(100.0, 200.0),
            Point(150.0, 150.0)  // Extra point
        )
        CornerOrderer.orderCorners(corners)
    }

    @Test(expected = IllegalArgumentException::class)
    fun orderCorners_emptyList_throwsException() {
        CornerOrderer.orderCorners(emptyList())
    }

    // ==================== UTILITY METHODS ====================

    @Test
    fun orderedCorners_width_calculatesCorrectly() {
        val corners = OrderedCorners(
            topLeft = Point(0.0, 0.0),
            topRight = Point(100.0, 0.0),
            bottomRight = Point(100.0, 50.0),
            bottomLeft = Point(0.0, 50.0)
        )

        assertEquals("width", 100.0, corners.width(), 0.01)
    }

    @Test
    fun orderedCorners_height_calculatesCorrectly() {
        val corners = OrderedCorners(
            topLeft = Point(0.0, 0.0),
            topRight = Point(100.0, 0.0),
            bottomRight = Point(100.0, 50.0),
            bottomLeft = Point(0.0, 50.0)
        )

        assertEquals("height", 50.0, corners.height(), 0.01)
    }

    @Test
    fun orderedCorners_toList_correctOrder() {
        val tl = Point(0.0, 0.0)
        val tr = Point(100.0, 0.0)
        val br = Point(100.0, 50.0)
        val bl = Point(0.0, 50.0)

        val corners = OrderedCorners(tl, tr, br, bl)
        val list = corners.toList()

        assertEquals(4, list.size)
        assertEquals(tl, list[0])
        assertEquals(tr, list[1])
        assertEquals(br, list[2])
        assertEquals(bl, list[3])
    }

    // ==================== HELPER ====================

    private fun assertEquals(msg: String, expected: Point, actual: Point) {
        assertEquals("$msg.x", expected.x, actual.x, 0.01)
        assertEquals("$msg.y", expected.y, actual.y, 0.01)
    }
}
