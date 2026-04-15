import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watermarking_core/watermarking_core.dart';

/// Mobile-specific implementation of DeviceService.
/// Uses platform channels to communicate with native iOS/Android code.
class MobileDeviceService implements DeviceService {
  MobileDeviceService();

  static const platform = MethodChannel('watermarking.enspyr.co/detect');

  /// For testing without native code
  Future<String> performFakeExtraction({
    required int width,
    required int height,
  }) async {
    final ByteData bytes = await rootBundle.load('assets/lena-6-hello.png');
    final ByteBuffer buffer = bytes.buffer;
    final String dir = (await getApplicationDocumentsDirectory()).path;
    await File('$dir/lena').writeAsBytes(
        buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    return '$dir/lena';
  }

  @override
  Future<String> performExtraction({
    required int width,
    required int height,
    required String imageUrl,
  }) async {
    String path = await platform.invokeMethod('startDetection', {
      'width': width,
      'height': height,
      'imageUrl': imageUrl,
    });
    platform.invokeMethod('dismiss');
    return path;
  }

  @override
  Future<int> findFileSize({required String path}) {
    return File(path).length();
  }
}
