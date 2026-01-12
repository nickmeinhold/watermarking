package co.enspyr.watermarking_mobile.detection

import android.graphics.Bitmap
import org.opencv.android.OpenCVLoader

/**
 * Real implementation of DetectionService using OpenCV.
 *
 * This wraps the existing detection components:
 * - RectangleDetector: Finds rectangle corners in the image
 * - CornerOrderer: Orders corners as TL, TR, BR, BL
 * - PerspectiveCorrector: Applies perspective transformation
 *
 * Confidence: 70% (limited by underlying components)
 */
class RealDetectionService(
    private val detector: RectangleDetector = RectangleDetector(),
    private val corrector: PerspectiveCorrector = PerspectiveCorrector()
) : DetectionService {

    override val serviceName: String = "RealDetectionService (OpenCV)"

    private var openCvInitialized = false

    /**
     * Initializes OpenCV if not already done.
     *
     * @return true if initialization succeeded
     */
    private fun ensureOpenCvInitialized(): Boolean {
        if (!openCvInitialized) {
            openCvInitialized = OpenCVLoader.initLocal()
        }
        return openCvInitialized
    }

    override fun detectAndCorrect(bitmap: Bitmap, outputWidth: Int): DetectionResult {
        val startTime = System.currentTimeMillis()

        // Initialize OpenCV
        if (!ensureOpenCvInitialized()) {
            return DetectionResult.Failure(
                reason = "Failed to initialize OpenCV",
                debugInfo = null
            )
        }

        // Step 1: Detect rectangle
        val debugResult = detector.detectWithDebug(bitmap)
        val corners = debugResult.selected

        if (corners == null || corners.size != 4) {
            return DetectionResult.Failure(
                reason = "No rectangle detected in image",
                debugInfo = debugResult
            )
        }

        // Step 2: Order corners
        val orderedCorners = try {
            CornerOrderer.orderCorners(corners)
        } catch (e: Exception) {
            return DetectionResult.Failure(
                reason = "Failed to order corners: ${e.message}",
                debugInfo = debugResult
            )
        }

        // Step 3: Apply perspective correction
        val correctedBitmap = try {
            corrector.correct(bitmap, orderedCorners, outputWidth)
        } catch (e: Exception) {
            return DetectionResult.Failure(
                reason = "Failed to apply perspective correction: ${e.message}",
                debugInfo = debugResult
            )
        }

        val processingTime = System.currentTimeMillis() - startTime

        return DetectionResult.Success(
            correctedBitmap = correctedBitmap,
            corners = orderedCorners,
            processingTimeMs = processingTime
        )
    }

    /**
     * Provides access to detector parameters for tuning.
     */
    fun getDetector(): RectangleDetector = detector

    /**
     * Configures detector with custom parameters.
     */
    fun configureDetector(
        cannyLow: Double? = null,
        cannyHigh: Double? = null,
        blurKernelSize: Int? = null,
        approxEpsilon: Double? = null,
        minAreaRatio: Double? = null,
        maxAreaRatio: Double? = null,
        minAspectRatio: Double? = null,
        quadratureTolerance: Double? = null
    ) {
        cannyLow?.let { detector.cannyLow = it }
        cannyHigh?.let { detector.cannyHigh = it }
        blurKernelSize?.let { detector.blurKernelSize = it }
        approxEpsilon?.let { detector.approxEpsilon = it }
        minAreaRatio?.let { detector.minAreaRatio = it }
        maxAreaRatio?.let { detector.maxAreaRatio = it }
        minAspectRatio?.let { detector.minAspectRatio = it }
        quadratureTolerance?.let { detector.quadratureTolerance = it }
    }

    companion object {
        /**
         * Creates a service with default parameters.
         */
        fun withDefaults(): RealDetectionService {
            return RealDetectionService()
        }

        /**
         * Creates a service with sensitive detection (lower thresholds).
         * Use for low-contrast images.
         */
        fun sensitive(): RealDetectionService {
            val service = RealDetectionService()
            service.configureDetector(
                cannyLow = 30.0,
                cannyHigh = 100.0,
                minAreaRatio = 0.15
            )
            return service
        }

        /**
         * Creates a service with strict detection (higher thresholds).
         * Use for noisy images to avoid false positives.
         */
        fun strict(): RealDetectionService {
            val service = RealDetectionService()
            service.configureDetector(
                cannyLow = 80.0,
                cannyHigh = 200.0,
                minAreaRatio = 0.30,
                quadratureTolerance = 15.0
            )
            return service
        }
    }
}
