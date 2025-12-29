import 'package:watermarking_core/models/bottom_nav_view_model.dart';
import 'package:watermarking_core/models/detection_items_view_model.dart';
import 'package:watermarking_core/models/original_image_reference.dart';
import 'package:watermarking_core/models/original_images_view_model.dart';
import 'package:watermarking_core/models/problem.dart';
import 'package:watermarking_core/models/user_model.dart';
import 'package:watermarking_core/utilities/hash_utilities.dart';

class AppState {
  const AppState({
    required this.user,
    required this.bottomNav,
    required this.originals,
    required this.detections,
    required this.problems,
  });

  final UserModel user;
  final BottomNavViewModel bottomNav;
  final OriginalImagesViewModel originals;
  final DetectionItemsViewModel detections;
  final List<Problem> problems;

  static AppState initialState() => AppState(
      user: UserModel(waiting: true),
      bottomNav: BottomNavViewModel(index: 0),
      originals: OriginalImagesViewModel(images: <OriginalImageReference>[]),
      detections: DetectionItemsViewModel(items: []),
      problems: <Problem>[]);

  AppState copyWith({
    UserModel? user,
    BottomNavViewModel? bottomNav,
    OriginalImagesViewModel? originals,
    DetectionItemsViewModel? detections,
    List<Problem>? problems,
  }) {
    return AppState(
        user: user ?? this.user,
        bottomNav: bottomNav ?? this.bottomNav,
        originals: originals ?? this.originals,
        detections: detections ?? this.detections,
        problems: problems ?? this.problems);
  }

  @override
  int get hashCode => hash5(user, bottomNav, originals, detections, problems);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          bottomNav == other.bottomNav &&
          originals == other.originals &&
          detections == other.detections &&
          problems == other.problems;

  @override
  String toString() {
    return 'AppState{user: $user, bottomNav: $bottomNav, originals: $originals, detections: $detections, problems: $problems}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user': user,
        'bottomNav': bottomNav,
        'originals': originals,
        'detections': detections,
        'problems': problems,
      };
}
