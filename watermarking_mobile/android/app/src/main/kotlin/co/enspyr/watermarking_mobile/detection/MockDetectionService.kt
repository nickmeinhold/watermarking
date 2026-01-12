package co.enspyr.watermarking_mobile.detection

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import org.opencv.core.Point

/**
 * Mock implementation of DetectionService for testing.
 *
 * This implementation does NOT use OpenCV. It:
 * - Always "succeeds" (or fails based on configuration)
 * - Returns a cropped/scaled version of the input as the "corrected" image
 * - Simulates processing delay
 * - Provides predictable results for UI testing
 *
 * Usage:
 *   val service = MockDetectionService(
 *       simulateFailure = false,
 *       simulatedDelayMs = 500
 *   )
 */
class MockDetectionService(
    private val simulateFailure: Boolean = false,
    private val failureReason: String = "Mock: No rectangle detected",
    private val simulatedDelayMs: Long = 200,
    private val addDebugOverlay: Boolean = true
) : DetectionService {

    override val serviceName: String = "MockDetectionService"

    override fun detectAndCorrect(bitmap: Bitmap, outputWidth: Int): DetectionResult {
        val startTime = System.currentTimeMillis()

        // Simulate processing time
        if (simulatedDelayMs > 0) {
            Thread.sleep(simulatedDelayMs)
        }

        // Simulate failure if configured
        if (simulateFailure) {
            return DetectionResult.Failure(
                reason = failureReason,
                debugInfo = null
            )
        }

        // Create fake "detected" corners (center 60% of image)
        val marginX = bitmap.width * 0.2
        val marginY = bitmap.height * 0.2
        val corners = OrderedCorners(
            topLeft = Point(marginX, marginY),
            topRight = Point(bitmap.width - marginX, marginY),
            bottomRight = Point(bitmap.width - marginX, bitmap.height - marginY),
            bottomLeft = Point(marginX, bitmap.height - marginY)
        )

        // Create "corrected" bitmap by cropping center region
        val correctedBitmap = createMockCorrectedBitmap(bitmap, corners, outputWidth)

        val processingTime = System.currentTimeMillis() - startTime

        return DetectionResult.Success(
            correctedBitmap = correctedBitmap,
            corners = corners,
            processingTimeMs = processingTime
        )
    }

    /**
     * Creates a mock "corrected" bitmap by:
     * 1. Cropping the center region (simulating detection)
     * 2. Scaling to output width
     * 3. Optionally adding a debug overlay
     */
    private fun createMockCorrectedBitmap(
        source: Bitmap,
        corners: OrderedCorners,
        outputWidth: Int
    ): Bitmap {
        // Calculate crop region
        val cropLeft = corners.topLeft.x.toInt()
        val cropTop = corners.topLeft.y.toInt()
        val cropWidth = (corners.topRight.x - corners.topLeft.x).toInt()
        val cropHeight = (corners.bottomLeft.y - corners.topLeft.y).toInt()

        // Calculate output dimensions preserving aspect ratio
        val aspectRatio = cropHeight.toFloat() / cropWidth.toFloat()
        val outputHeight = (outputWidth * aspectRatio).toInt()

        // Create output bitmap
        val output = Bitmap.createBitmap(outputWidth, outputHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        // Draw cropped and scaled source
        val srcRect = Rect(cropLeft, cropTop, cropLeft + cropWidth, cropTop + cropHeight)
        val dstRect = Rect(0, 0, outputWidth, outputHeight)
        canvas.drawBitmap(source, srcRect, dstRect, null)

        // Add debug overlay if enabled
        if (addDebugOverlay) {
            drawDebugOverlay(canvas, outputWidth, outputHeight)
        }

        return output
    }

    /**
     * Draws a debug overlay to make it obvious this is a mock result.
     */
    private fun drawDebugOverlay(canvas: Canvas, width: Int, height: Int) {
        val paint = Paint().apply {
            color = Color.argb(180, 255, 0, 0)  // Semi-transparent red
            textSize = width / 15f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }

        // Draw "MOCK" text
        canvas.drawText(
            "MOCK DETECTION",
            width / 2f,
            height / 2f,
            paint
        )

        // Draw border
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 8f
        paint.color = Color.RED
        canvas.drawRect(4f, 4f, width - 4f, height - 4f, paint)
    }

    companion object {
        /**
         * Creates a mock service that always succeeds with minimal delay.
         */
        fun alwaysSucceeds(): MockDetectionService {
            return MockDetectionService(
                simulateFailure = false,
                simulatedDelayMs = 100,
                addDebugOverlay = true
            )
        }

        /**
         * Creates a mock service that always fails.
         */
        fun alwaysFails(reason: String = "Mock: Simulated detection failure"): MockDetectionService {
            return MockDetectionService(
                simulateFailure = true,
                failureReason = reason
            )
        }

        /**
         * Creates a mock service with realistic delay (for UX testing).
         */
        fun withRealisticDelay(): MockDetectionService {
            return MockDetectionService(
                simulateFailure = false,
                simulatedDelayMs = 1500,  // 1.5 seconds like real detection
                addDebugOverlay = true
            )
        }

        /**
         * Creates a mock service without debug overlay (for screenshot testing).
         */
        fun forScreenshots(): MockDetectionService {
            return MockDetectionService(
                simulateFailure = false,
                simulatedDelayMs = 0,
                addDebugOverlay = false
            )
        }
    }
}
