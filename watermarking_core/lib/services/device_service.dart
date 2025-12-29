/// Abstract interface for device-specific operations.
///
/// Mobile apps implement this with platform channels (ARKit/ARCore).
/// Web apps implement this with file picker + canvas APIs.
abstract class DeviceService {
  /// Perform image extraction/detection.
  /// Returns the path to the extracted image file.
  Future<String> performExtraction({
    required int width,
    required int height,
  });

  /// Find the size of a file in bytes.
  Future<int> findFileSize({required String path});
}
