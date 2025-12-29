import 'package:watermarking_core/models/original_image_reference.dart';
import 'package:watermarking_core/utilities/hash_utilities.dart';

class OriginalImagesViewModel {
  const OriginalImagesViewModel({
    this.images = const [],
    this.selectedImage,
    this.selectedWidth,
    this.selectedHeight,
  });

  final List<OriginalImageReference> images;
  final OriginalImageReference? selectedImage;
  final int? selectedWidth;
  final int? selectedHeight;

  OriginalImagesViewModel copyWith({
    List<OriginalImageReference>? images,
    OriginalImageReference? selectedImage,
    int? selectedWidth,
    int? selectedHeight,
  }) {
    return OriginalImagesViewModel(
      images: images ?? this.images,
      selectedImage: selectedImage ?? this.selectedImage,
      selectedWidth: selectedWidth ?? this.selectedWidth,
      selectedHeight: selectedHeight ?? this.selectedHeight,
    );
  }

  @override
  int get hashCode =>
      hash4(hashObjects(images), selectedImage, selectedWidth, selectedHeight);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OriginalImagesViewModel &&
          runtimeType == other.runtimeType &&
          images == other.images &&
          selectedImage == other.selectedImage &&
          selectedWidth == other.selectedWidth &&
          selectedHeight == other.selectedHeight;

  @override
  String toString() {
    return 'OriginalImagesViewModel{images: $images, selectedImage: $selectedImage, selectedWidth: $selectedWidth, selectedHeight: $selectedHeight}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'images': images,
        'selectedImage': selectedImage,
        'selectedWidth': selectedWidth,
        'selectedHeight': selectedHeight,
      };
}
