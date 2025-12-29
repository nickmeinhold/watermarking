import 'package:watermarking_core/models/marked_image_reference.dart';
import 'package:watermarking_core/utilities/hash_utilities.dart';
import 'package:watermarking_core/utilities/string_utilities.dart';

class OriginalImageReference {
  const OriginalImageReference({
    this.id,
    this.name,
    this.filePath,
    this.url,
    this.markedImages = const [],
  });

  final String? id;
  final String? name;
  final String? filePath;
  final String? url;
  final List<MarkedImageReference> markedImages;

  /// Number of marked versions of this image
  int get markedCount => markedImages.length;

  OriginalImageReference copyWith({
    String? id,
    String? name,
    String? filePath,
    String? url,
    List<MarkedImageReference>? markedImages,
  }) {
    return OriginalImageReference(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      url: url ?? this.url,
      markedImages: markedImages ?? this.markedImages,
    );
  }

  @override
  int get hashCode => hash4(id, name, filePath, hashObjects(markedImages));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OriginalImageReference &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          filePath == other.filePath &&
          url == other.url &&
          markedImages.length == other.markedImages.length;

  @override
  String toString() {
    final String? trimmedUrl = trimToLast(15, url);
    return 'ImageReference{uid: $id, name: $name, filePath: $filePath, url: $trimmedUrl, markedCount: $markedCount}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'filePath': filePath,
        'url': url,
        'markedImages': markedImages.map((m) => m.toJson()).toList(),
      };
}
