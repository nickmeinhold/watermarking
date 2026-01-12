package co.enspyr.watermarking_mobile.detection

import android.graphics.Bitmap

/**
 * Interface for rectangle detection and perspective correction.
 *
 * This abstraction allows swapping between:
 * - RealDetectionService: Uses OpenCV for actual detection
 * - MockDetectionService: Returns fake results for testing
 *
 * Benefits:
 * - Test Flutter ↔ Native integration without OpenCV
 * - Faster development iteration
 * - Predictable results for UI testing
 * - A/B testing between implementations
 */
interface DetectionService {

    /**
     * Detects a rectangle in the image and returns a perspective-corrected version.
     *
     * @param bitmap The input image
     * @param outputWidth Desired width of corrected output (default 512)
     * @return DetectionResult containing the corrected image or error
     */
    fun detectAndCorrect(bitmap: Bitmap, outputWidth: Int = 512): DetectionResult

    /**
     * Returns the name of this implementation (for logging/debugging).
     */
    val serviceName: String
}

/**
 * Result of detection operation.
 */
sealed class DetectionResult {
    /**
     * Detection succeeded.
     *
     * @param correctedBitmap The perspective-corrected image
     * @param corners The detected corners (for debugging)
     * @param processingTimeMs Time taken for detection + correction
     */
    data class Success(
        val correctedBitmap: Bitmap,
        val corners: OrderedCorners,
        val processingTimeMs: Long
    ) : DetectionResult()

    /**
     * Detection failed.
     *
     * @param reason Human-readable error message
     * @param debugInfo Optional debug information
     */
    data class Failure(
        val reason: String,
        val debugInfo: DetectionDebugResult? = null
    ) : DetectionResult()
}
