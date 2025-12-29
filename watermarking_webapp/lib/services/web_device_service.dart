import 'package:watermarking_core/watermarking_core.dart';

/// Web implementation of DeviceService.
/// Web uses file upload for detection rather than camera capture,
/// so these methods are not used in the same way as mobile.
class WebDeviceService implements DeviceService {
  @override
  Future<String> performExtraction({required int width, required int height}) {
    // Web detection uses file upload, not camera capture
    throw UnsupportedError('Web does not support camera extraction. Use file upload instead.');
  }

  @override
  Future<int> findFileSize({required String path}) {
    // Web files are handled differently via file_picker
    throw UnsupportedError('Web does not support local file paths.');
  }
}
