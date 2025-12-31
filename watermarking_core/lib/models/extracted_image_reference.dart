import 'package:watermarking_core/models/file_upload.dart';
import 'package:watermarking_core/utilities/hash_utilities.dart';

class ExtractedImageReference {
  const ExtractedImageReference({
    this.localPath,
    this.bytes,
    this.remotePath,
    this.servingUrl,
    this.upload,
  });

  final String? localPath;
  final int? bytes;
  final String? remotePath;
  final String? servingUrl;
  final FileUpload? upload;

  ExtractedImageReference copyWith({
    String? localPath,
    int? bytes,
    String? remotePath,
    String? servingUrl,
    FileUpload? upload,
  }) {
    return ExtractedImageReference(
      localPath: localPath ?? this.localPath,
      bytes: bytes ?? this.bytes,
      remotePath: remotePath ?? this.remotePath,
      servingUrl: servingUrl ?? this.servingUrl,
      upload: upload ?? this.upload,
    );
  }

  @override
  int get hashCode =>
      hashObjects([localPath, bytes, remotePath, servingUrl, upload]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedImageReference &&
          runtimeType == other.runtimeType &&
          localPath == other.localPath &&
          bytes == other.bytes &&
          remotePath == other.remotePath &&
          servingUrl == other.servingUrl &&
          upload == other.upload;

  @override
  String toString() {
    return 'ImageReference{localPath: $localPath, bytes: $bytes, remotePath: $remotePath, servingUrl: $servingUrl, upload: $upload}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'localPath': localPath,
        'bytes': bytes,
        'remotePath': remotePath,
        'servingUrl': servingUrl,
        'upload': upload,
      };
}
