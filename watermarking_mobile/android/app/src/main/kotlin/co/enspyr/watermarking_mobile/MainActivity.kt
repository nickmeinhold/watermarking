package co.enspyr.watermarking_mobile

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import co.enspyr.watermarking_mobile.detection.DetectionResult
import co.enspyr.watermarking_mobile.detection.DetectionService
import co.enspyr.watermarking_mobile.detection.MockDetectionService
import co.enspyr.watermarking_mobile.detection.RealDetectionService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * Main activity handling Flutter method channel for rectangle detection.
 *
 * Supports two modes via BuildConfig or method channel parameter:
 * - Real mode: Uses OpenCV for actual detection (RealDetectionService)
 * - Mock mode: Returns fake results for testing (MockDetectionService)
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "watermarking.enspyr.co/detect"
        private const val TAG = "MainActivity"

        /**
         * Set to true to use mock detection (no OpenCV required).
         * Useful for UI testing and development without Android SDK.
         */
        private const val USE_MOCK_DETECTION = true  // TODO: Set to false for production
    }

    private var pendingResult: MethodChannel.Result? = null
    private lateinit var imagePickerLauncher: ActivityResultLauncher<Intent>

    // Detection service - can be swapped between real and mock
    private lateinit var detectionService: DetectionService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize detection service based on configuration
        detectionService = createDetectionService()
        android.util.Log.d(TAG, "Using detection service: ${detectionService.serviceName}")

        // Register activity result launcher for image picker
        imagePickerLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result ->
            handleImagePickerResult(result.resultCode, result.data)
        }
    }

    /**
     * Creates the detection service based on configuration.
     * Override this method to inject a different service for testing.
     */
    private fun createDetectionService(): DetectionService {
        return if (USE_MOCK_DETECTION) {
            android.util.Log.w(TAG, "⚠️ MOCK MODE: Using fake detection service")
            MockDetectionService.alwaysSucceeds()
        } else {
            RealDetectionService.withDefaults()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startDetection" -> {
                        // Check for mock mode override from Flutter
                        val useMock = call.argument<Boolean>("useMock") ?: USE_MOCK_DETECTION
                        if (useMock && detectionService !is MockDetectionService) {
                            detectionService = MockDetectionService.alwaysSucceeds()
                            android.util.Log.d(TAG, "Switched to mock service via parameter")
                        }

                        pendingResult = result
                        openGalleryPicker()
                    }
                    "setMockMode" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        detectionService = if (enabled) {
                            MockDetectionService.alwaysSucceeds()
                        } else {
                            RealDetectionService.withDefaults()
                        }
                        android.util.Log.d(TAG, "Mock mode set to: $enabled")
                        result.success(null)
                    }
                    "getServiceInfo" -> {
                        result.success(mapOf(
                            "serviceName" to detectionService.serviceName,
                            "isMock" to (detectionService is MockDetectionService)
                        ))
                    }
                    "dismiss" -> {
                        // No-op for gallery picker (it dismisses itself)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openGalleryPicker() {
        val intent = Intent(Intent.ACTION_PICK).apply {
            type = "image/*"
        }
        imagePickerLauncher.launch(intent)
    }

    private fun handleImagePickerResult(resultCode: Int, data: Intent?) {
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pendingResult?.error("CANCELLED", "Image selection was cancelled", null)
            pendingResult = null
            return
        }

        val imageUri = data.data!!

        // Process image in background
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val filePath = withContext(Dispatchers.IO) {
                    processImage(imageUri)
                }

                if (filePath != null) {
                    pendingResult?.success(filePath)
                } else {
                    pendingResult?.error("NO_RECTANGLE", "No rectangle detected in image", null)
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error processing image", e)
                pendingResult?.error("PROCESSING_ERROR", e.message, null)
            } finally {
                pendingResult = null
            }
        }
    }

    private fun processImage(imageUri: Uri): String? {
        // Load bitmap from URI
        val inputStream = contentResolver.openInputStream(imageUri)
            ?: throw Exception("Failed to open image")

        val originalBitmap = BitmapFactory.decodeStream(inputStream)
        inputStream.close()

        if (originalBitmap == null) {
            throw Exception("Failed to decode image")
        }

        android.util.Log.d(TAG, "Loaded image: ${originalBitmap.width}x${originalBitmap.height}")
        android.util.Log.d(TAG, "Processing with: ${detectionService.serviceName}")

        // Use detection service
        val result = detectionService.detectAndCorrect(originalBitmap)

        return when (result) {
            is DetectionResult.Success -> {
                android.util.Log.d(TAG, "Detection succeeded in ${result.processingTimeMs}ms")

                // Save to cache directory with unique name
                val timestamp = System.currentTimeMillis()
                val outputFile = File(cacheDir, "detected_image_$timestamp.png")
                FileOutputStream(outputFile).use { out ->
                    result.correctedBitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                }

                // Cleanup
                originalBitmap.recycle()
                result.correctedBitmap.recycle()

                android.util.Log.d(TAG, "Saved corrected image to: ${outputFile.absolutePath}")
                outputFile.absolutePath
            }

            is DetectionResult.Failure -> {
                android.util.Log.d(TAG, "Detection failed: ${result.reason}")
                originalBitmap.recycle()
                result.debugInfo?.edges?.recycle()
                null
            }
        }
    }
}
