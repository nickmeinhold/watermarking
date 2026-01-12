package co.enspyr.watermarking_mobile.detection

import android.graphics.Bitmap
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import kotlin.math.abs
import kotlin.math.atan2

/**
 * Detects rectangles in images using OpenCV.
 *
 * Uses classical computer vision approach:
 * 1. Convert to grayscale
 * 2. Apply Gaussian blur to reduce noise
 * 3. Canny edge detection
 * 4. Find contours
 * 5. Approximate contours to polygons
 * 6. Filter for quadrilaterals matching size/shape criteria
 *
 * Parameters are tunable for different lighting conditions and image types.
 */
class RectangleDetector {

    // Tunable parameters (matching iOS VNDetectRectanglesRequest where applicable)
    var cannyLow: Double = 50.0
    var cannyHigh: Double = 150.0
    var blurKernelSize: Int = 5
    var approxEpsilon: Double = 0.02  // Multiplied by perimeter
    var minAreaRatio: Double = 0.25   // Rectangle must be at least 25% of image area
    var maxAreaRatio: Double = 0.95   // Rectangle must be at most 95% of image area
    var minAspectRatio: Double = 0.3  // Minimum width/height ratio (iOS: 0.3)
    var quadratureTolerance: Double = 20.0  // Corner angle tolerance in degrees (iOS: 20)

    /**
     * Detects the largest valid rectangle in the image.
     *
     * @param bitmap Input image
     * @return List of 4 corner points if a rectangle is found, null otherwise
     */
    fun detect(bitmap: Bitmap): List<Point>? {
        val result = detectWithDebug(bitmap)
        return result.selected
    }

    /**
     * Detects rectangles with full debug information.
     *
     * @param bitmap Input image
     * @return DetectionDebugResult with intermediate processing results
     */
    fun detectWithDebug(bitmap: Bitmap): DetectionDebugResult {
        // Convert Bitmap to OpenCV Mat
        val mat = Mat()
        Utils.bitmapToMat(bitmap, mat)

        // Convert to grayscale
        val gray = Mat()
        Imgproc.cvtColor(mat, gray, Imgproc.COLOR_RGBA2GRAY)

        // Apply Gaussian blur to reduce noise
        val blurred = Mat()
        Imgproc.GaussianBlur(gray, blurred, Size(blurKernelSize.toDouble(), blurKernelSize.toDouble()), 0.0)

        // Canny edge detection
        val edges = Mat()
        Imgproc.Canny(blurred, edges, cannyLow, cannyHigh)

        // Dilate edges to close gaps
        val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(3.0, 3.0))
        val dilated = Mat()
        Imgproc.dilate(edges, dilated, kernel)

        // Convert edges to bitmap for debug output
        val edgesBitmap = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        val edgesRgba = Mat()
        Imgproc.cvtColor(dilated, edgesRgba, Imgproc.COLOR_GRAY2RGBA)
        Utils.matToBitmap(edgesRgba, edgesBitmap)

        // Find contours
        val contours = mutableListOf<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(dilated, contours, hierarchy, Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE)

        // Find valid quadrilaterals
        val imageArea = bitmap.width * bitmap.height
        val candidates = mutableListOf<MatOfPoint2f>()
        var bestQuad: MatOfPoint2f? = null
        var bestArea = 0.0

        for (contour in contours) {
            // Approximate contour to polygon
            val contour2f = MatOfPoint2f(*contour.toArray())
            val perimeter = Imgproc.arcLength(contour2f, true)
            val approx = MatOfPoint2f()
            Imgproc.approxPolyDP(contour2f, approx, approxEpsilon * perimeter, true)

            // Check if it's a quadrilateral
            if (approx.rows() == 4) {
                val area = Imgproc.contourArea(approx)
                val areaRatio = area / imageArea

                // Check size constraints
                if (areaRatio >= minAreaRatio && areaRatio <= maxAreaRatio) {
                    // Check aspect ratio
                    val rect = Imgproc.boundingRect(MatOfPoint(*approx.toArray().map {
                        org.opencv.core.Point(it.x, it.y)
                    }.toTypedArray()))

                    val aspectRatio = minOf(rect.width, rect.height).toDouble() /
                            maxOf(rect.width, rect.height).toDouble()

                    if (aspectRatio >= minAspectRatio) {
                        // Check quadrature tolerance (corners should be ~90 degrees)
                        if (checkQuadratureTolerance(approx)) {
                            candidates.add(approx)

                            // Keep track of the largest valid quadrilateral
                            if (area > bestArea) {
                                bestArea = area
                                bestQuad = approx
                            }
                        }
                    }
                }
            }

            contour2f.release()
        }

        // Extract corners from best quadrilateral
        val selected = bestQuad?.toArray()?.toList()

        // Cleanup
        mat.release()
        gray.release()
        blurred.release()
        edges.release()
        kernel.release()
        dilated.release()
        edgesRgba.release()
        hierarchy.release()
        contours.forEach { it.release() }

        return DetectionDebugResult(
            edges = edgesBitmap,
            contours = contours.size,
            candidates = candidates.size,
            selected = selected
        )
    }

    /**
     * Checks if all corners of the quadrilateral are approximately 90 degrees.
     */
    private fun checkQuadratureTolerance(approx: MatOfPoint2f): Boolean {
        val points = approx.toArray()
        if (points.size != 4) return false

        for (i in 0 until 4) {
            val p1 = points[i]
            val p2 = points[(i + 1) % 4]
            val p3 = points[(i + 2) % 4]

            val angle = calculateAngle(p1, p2, p3)
            val deviation = abs(90.0 - angle)

            if (deviation > quadratureTolerance) {
                return false
            }
        }
        return true
    }

    /**
     * Calculates the angle at p2 formed by p1-p2-p3.
     */
    private fun calculateAngle(p1: Point, p2: Point, p3: Point): Double {
        val v1x = p1.x - p2.x
        val v1y = p1.y - p2.y
        val v2x = p3.x - p2.x
        val v2y = p3.y - p2.y

        val angle1 = atan2(v1y, v1x)
        val angle2 = atan2(v2y, v2x)
        var angle = Math.toDegrees(abs(angle1 - angle2))

        if (angle > 180) angle = 360 - angle
        return angle
    }
}

/**
 * Debug result containing intermediate processing outputs.
 */
data class DetectionDebugResult(
    val edges: Bitmap,      // Canny edge detection output
    val contours: Int,      // Number of contours found
    val candidates: Int,    // Number of valid quadrilaterals
    val selected: List<Point>?  // The selected rectangle corners (largest valid quad)
)
