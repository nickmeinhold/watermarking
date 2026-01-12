package co.enspyr.watermarking_mobile.detection

import android.graphics.Bitmap
import org.opencv.android.Utils
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc

/**
 * Applies perspective correction to extract a rectangular region from an image.
 *
 * Takes the detected corners and transforms the skewed quadrilateral
 * into a proper rectangle, correcting for perspective distortion.
 *
 * Uses OpenCV's getPerspectiveTransform and warpPerspective with
 * high-quality Lanczos interpolation (matching iOS CILanczosScaleTransform).
 */
class PerspectiveCorrector {

    /**
     * Applies perspective correction to extract the rectangle.
     *
     * @param source The original image
     * @param corners Ordered corners of the detected rectangle
     * @param outputWidth Desired width of output image (default 512 to match iOS)
     * @return Perspective-corrected bitmap
     */
    fun correct(source: Bitmap, corners: OrderedCorners, outputWidth: Int = 512): Bitmap {
        // Calculate output dimensions preserving aspect ratio
        val srcWidth = corners.width()
        val srcHeight = corners.height()
        val aspectRatio = srcHeight / srcWidth
        val outputHeight = (outputWidth * aspectRatio).toInt()

        // Convert source bitmap to Mat
        val sourceMat = Mat()
        Utils.bitmapToMat(source, sourceMat)

        // Define source points (the detected corners)
        val srcPoints = MatOfPoint2f(
            corners.topLeft,
            corners.topRight,
            corners.bottomRight,
            corners.bottomLeft
        )

        // Define destination points (perfect rectangle)
        val dstPoints = MatOfPoint2f(
            Point(0.0, 0.0),
            Point(outputWidth - 1.0, 0.0),
            Point(outputWidth - 1.0, outputHeight - 1.0),
            Point(0.0, outputHeight - 1.0)
        )

        // Calculate perspective transform matrix
        val transformMatrix = Imgproc.getPerspectiveTransform(srcPoints, dstPoints)

        // Apply perspective warp with high-quality interpolation
        val outputMat = Mat()
        Imgproc.warpPerspective(
            sourceMat,
            outputMat,
            transformMatrix,
            Size(outputWidth.toDouble(), outputHeight.toDouble()),
            Imgproc.INTER_LANCZOS4  // High-quality interpolation matching iOS
        )

        // Convert result to Bitmap
        val outputBitmap = Bitmap.createBitmap(outputWidth, outputHeight, Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(outputMat, outputBitmap)

        // Cleanup
        sourceMat.release()
        srcPoints.release()
        dstPoints.release()
        transformMatrix.release()
        outputMat.release()

        return outputBitmap
    }

    /**
     * Convenience method that detects, orders corners, and corrects in one call.
     *
     * @param source The original image
     * @param corners Unordered list of 4 corner points
     * @param outputWidth Desired width of output image
     * @return Perspective-corrected bitmap
     */
    fun correctWithUnorderedCorners(
        source: Bitmap,
        corners: List<Point>,
        outputWidth: Int = 512
    ): Bitmap {
        val orderedCorners = CornerOrderer.orderCorners(corners)
        return correct(source, orderedCorners, outputWidth)
    }
}
