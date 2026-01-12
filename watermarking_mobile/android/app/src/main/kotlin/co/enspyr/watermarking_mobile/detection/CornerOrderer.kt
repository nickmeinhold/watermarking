package co.enspyr.watermarking_mobile.detection

import org.opencv.core.Point

/**
 * Orders 4 detected corner points into a consistent order:
 * topLeft, topRight, bottomRight, bottomLeft
 *
 * This is necessary because OpenCV's contour detection returns corners
 * in an arbitrary order, while perspective correction requires them
 * in a specific order.
 *
 * Algorithm:
 * - Sort by sum (x + y): smallest = top-left, largest = bottom-right
 * - Sort by difference (y - x): smallest = top-right, largest = bottom-left
 */
object CornerOrderer {

    /**
     * Orders 4 corner points into topLeft, topRight, bottomRight, bottomLeft.
     *
     * @param corners List of exactly 4 points
     * @return OrderedCorners with points in consistent order
     * @throws IllegalArgumentException if corners.size != 4
     */
    fun orderCorners(corners: List<Point>): OrderedCorners {
        require(corners.size == 4) { "Expected 4 corners, got ${corners.size}" }

        // Sort by sum (x + y)
        // Smallest sum = top-left (closest to origin)
        // Largest sum = bottom-right (farthest from origin)
        val sortedBySum = corners.sortedBy { it.x + it.y }
        val topLeft = sortedBySum[0]
        val bottomRight = sortedBySum[3]

        // Sort by difference (y - x)
        // Smallest difference = top-right (high x, low y)
        // Largest difference = bottom-left (low x, high y)
        val sortedByDiff = corners.sortedBy { it.y - it.x }
        val topRight = sortedByDiff[0]
        val bottomLeft = sortedByDiff[3]

        return OrderedCorners(
            topLeft = topLeft,
            topRight = topRight,
            bottomRight = bottomRight,
            bottomLeft = bottomLeft
        )
    }
}

/**
 * Represents 4 corners of a quadrilateral in a consistent order.
 */
data class OrderedCorners(
    val topLeft: Point,
    val topRight: Point,
    val bottomRight: Point,
    val bottomLeft: Point
) {
    /**
     * Returns corners as a list in order: TL, TR, BR, BL
     */
    fun toList(): List<Point> = listOf(topLeft, topRight, bottomRight, bottomLeft)

    /**
     * Calculates the width of the quadrilateral (average of top and bottom edges)
     */
    fun width(): Double {
        val topWidth = distance(topLeft, topRight)
        val bottomWidth = distance(bottomLeft, bottomRight)
        return maxOf(topWidth, bottomWidth)
    }

    /**
     * Calculates the height of the quadrilateral (average of left and right edges)
     */
    fun height(): Double {
        val leftHeight = distance(topLeft, bottomLeft)
        val rightHeight = distance(topRight, bottomRight)
        return maxOf(leftHeight, rightHeight)
    }

    private fun distance(p1: Point, p2: Point): Double {
        val dx = p1.x - p2.x
        val dy = p1.y - p2.y
        return kotlin.math.sqrt(dx * dx + dy * dy)
    }
}
