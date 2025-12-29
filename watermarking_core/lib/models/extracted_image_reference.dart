import 'package:watermarking_core/models/file_upload.dart';
import 'package:watermarking_core/utilities/hash_utilities.dart';

class ExtractedImageReference {
  const ExtractedImageReference({
    this.localPath,
    this.bytes,
    this.remotePath,
    this.upload,
  });

  final String? localPath;
  final int? bytes;
  final String? remotePath;
  final FileUpload? upload;

  ExtractedImageReference copyWith({
    String? localPath,
    int? bytes,
    String? remotePath,
    FileUpload? upload,
  }) {
    return ExtractedImageReference(
      localPath: localPath ?? this.localPath,
      bytes: bytes ?? this.bytes,
      remotePath: remotePath ?? this.remotePath,
      upload: upload ?? this.upload,
    );
  }

  @override
  int get hashCode => hashObjects([localPath, bytes, remotePath, upload]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedImageReference &&
          runtimeType == other.runtimeType &&
          localPath == other.localPath &&
          bytes == other.bytes &&
          remotePath == other.remotePath &&
          upload == other.upload;

  @override
  String toString() {
    return 'ImageReference{localPath: $localPath, bytes: $bytes, remotePath: $remotePath, upload: $upload}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'localPath': localPath,
        'bytes': bytes,
        'remotePath': remotePath,
        'upload': upload,
      };
}
