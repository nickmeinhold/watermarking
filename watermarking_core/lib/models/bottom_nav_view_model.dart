import 'package:watermarking_core/utilities/hash_utilities.dart';

class BottomNavViewModel {
  const BottomNavViewModel({this.index = 0, this.shouldShowBottomSheet = false});

  final int index;
  final bool shouldShowBottomSheet;

  BottomNavViewModel copyWith({
    int? index,
    bool? shouldShowBottomSheet,
  }) {
    return BottomNavViewModel(
        index: index ?? this.index,
        shouldShowBottomSheet:
            shouldShowBottomSheet ?? this.shouldShowBottomSheet);
  }

  @override
  int get hashCode => hash2(index, shouldShowBottomSheet);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BottomNavViewModel &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          shouldShowBottomSheet == other.shouldShowBottomSheet;

  @override
  String toString() {
    return 'BottomNavViewModel{index: $index, shouldShowBottomSheet: $shouldShowBottomSheet}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'index': index,
        'shouldShowBottomSheet': shouldShowBottomSheet,
      };
}
