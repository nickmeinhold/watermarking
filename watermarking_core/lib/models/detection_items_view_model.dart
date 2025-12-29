import 'package:watermarking_core/models/detection_item.dart';
import 'package:watermarking_core/utilities/hash_utilities.dart';

class DetectionItemsViewModel {
  const DetectionItemsViewModel({this.items = const []});

  final List<DetectionItem> items;

  DetectionItemsViewModel copyWith({List<DetectionItem>? items}) {
    return DetectionItemsViewModel(items: items ?? this.items);
  }

  @override
  int get hashCode => hashObjects(items);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectionItemsViewModel &&
          runtimeType == other.runtimeType &&
          items == other.items;

  @override
  String toString() {
    return 'ImagesViewModel{items: $items}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'items': items};
}
