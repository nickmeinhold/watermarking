import 'package:redux/redux.dart';
import 'package:watermarking_core/models/app_state.dart';
import 'package:watermarking_core/models/detection_item.dart';
import 'package:watermarking_core/models/extracted_image_reference.dart';
import 'package:watermarking_core/models/file_upload.dart';
import 'package:watermarking_core/models/marked_image_reference.dart';
import 'package:watermarking_core/models/original_image_reference.dart';
import 'package:watermarking_core/models/original_images_view_model.dart';
import 'package:watermarking_core/models/problem.dart';
import 'package:watermarking_core/models/user_model.dart';
import 'package:watermarking_core/redux/actions.dart';

/// Reducer
final Reducer<AppState> appReducer =
    combineReducers<AppState>(<Reducer<AppState>>[
  TypedReducer<AppState, ActionSetAuthState>(_setAuthState),
  TypedReducer<AppState, ActionSetProfilePicUrl>(_setProfilePicUrl),
  TypedReducer<AppState, ActionSetOriginalImages>(_setOriginalImages),
  TypedReducer<AppState, ActionUpdateMarkedImages>(_updateMarkedImages),
  TypedReducer<AppState, ActionSetDetectionItems>(_setDetectionItems),
  TypedReducer<AppState, ActionSetBottomNav>(_setBottomNav),
  TypedReducer<AppState, ActionShowBottomSheet>(_setBottomSheet),
  TypedReducer<AppState, ActionSetSelectedImage>(_setSelectedImage),
  TypedReducer<AppState, ActionAddDetectionItem>(_addDetectionItem),
  TypedReducer<AppState, ActionStartUpload>(_setUploadStartTime),
  TypedReducer<AppState, ActionSetUploadProgress>(_setUploadProgress),
  TypedReducer<AppState, ActionSetUploadSuccess>(_setUploadSucceeded),
  TypedReducer<AppState, ActionSetDetectingProgress>(_setDetectingProgress),
  TypedReducer<AppState, ActionAddProblem>(_addProblem),
  TypedReducer<AppState, ActionRemoveProblem>(_removeProblem),
]);

AppState _setAuthState(
        AppState state, ActionSetAuthState action) =>
    state.copyWith(
        user: UserModel(
            id: action.userId, photoUrl: action.photoUrl, waiting: false));

AppState _setProfilePicUrl(AppState state, ActionSetProfilePicUrl action) {
  final UserModel newUserModel = state.user.copyWith(photoUrl: action.url);
  return state.copyWith(user: newUserModel);
}

AppState _setOriginalImages(AppState state, ActionSetOriginalImages action) {
  return state.copyWith(
      originals: OriginalImagesViewModel(images: action.images));
}

AppState _updateMarkedImages(AppState state, ActionUpdateMarkedImages action) {
  // Update each original image with its marked images
  final updatedImages = state.originals.images.map((original) {
    final markedData = action.markedImagesByOriginal[original.id] ?? [];
    final markedImages = markedData
        .map((data) => MarkedImageReference(
              id: data['id'] as String?,
              message: data['message'] as String?,
              name: data['name'] as String?,
              strength: data['strength'] as int?,
              path: data['path'] as String?,
              servingUrl: data['servingUrl'] as String?,
              progress: data['progress'] as String?,
            ))
        .toList();
    return original.copyWith(markedImages: markedImages);
  }).toList();

  // Also update selectedImage if it exists
  final selectedImage = state.originals.selectedImage;
  OriginalImageReference? updatedSelectedImage;
  if (selectedImage != null) {
    final markedData = action.markedImagesByOriginal[selectedImage.id] ?? [];
    final markedImages = markedData
        .map((data) => MarkedImageReference(
              id: data['id'] as String?,
              message: data['message'] as String?,
              name: data['name'] as String?,
              strength: data['strength'] as int?,
              path: data['path'] as String?,
              servingUrl: data['servingUrl'] as String?,
              progress: data['progress'] as String?,
            ))
        .toList();
    updatedSelectedImage = selectedImage.copyWith(markedImages: markedImages);
  }

  return state.copyWith(
    originals: state.originals.copyWith(
      images: updatedImages,
      selectedImage: updatedSelectedImage,
    ),
  );
}

AppState _setBottomNav(AppState state, ActionSetBottomNav action) {
  return state.copyWith(
      bottomNav: state.bottomNav.copyWith(index: action.index));
}

AppState _setBottomSheet(AppState state, ActionShowBottomSheet action) {
  return state.copyWith(
      bottomNav: state.bottomNav.copyWith(shouldShowBottomSheet: action.show));
}

AppState _setSelectedImage(AppState state, ActionSetSelectedImage action) {
  return state.copyWith(
      originals: state.originals.copyWith(
          selectedImage: action.image,
          selectedWidth: action.width,
          selectedHeight: action.height),
      bottomNav: state.bottomNav.copyWith(shouldShowBottomSheet: false));
}

AppState _setDetectionItems(AppState state, ActionSetDetectionItems action) {
  return state.copyWith(
      detections: state.detections.copyWith(items: action.items));
}

AppState _addDetectionItem(AppState state, ActionAddDetectionItem action) {
  final ExtractedImageReference newRef = ExtractedImageReference(
      bytes: action.bytes,
      localPath: action.extractedPath,
      upload: const FileUpload(bytesSent: 0, percent: 0));

  final DetectionItem newItem = DetectionItem(
    id: action.id,
    extractedRef: newRef,
    originalRef: state.originals.selectedImage,
    started: DateTime.now(),
  );

  return state.copyWith(
      detections: state.detections
          .copyWith(items: [newItem, ...state.detections.items]));
}

AppState _setUploadStartTime(AppState state, ActionStartUpload action) {
  final List<DetectionItem> nextItems = state.detections.items
      .map<DetectionItem>((DetectionItem item) => (item.id == action.id)
          ? item.copyWith(
              extractedRef: item.extractedRef?.copyWith(
                  upload: item.extractedRef?.upload
                      ?.copyWith(started: DateTime.now())))
          : item)
      .toList();

  return state.copyWith(
      detections: state.detections.copyWith(items: nextItems));
}

AppState _setUploadProgress(AppState state, ActionSetUploadProgress action) {
  final List<DetectionItem> nextItems =
      state.detections.items.map<DetectionItem>((DetectionItem item) {
    if (item.id != action.id) return item;
    final totalBytes = item.extractedRef?.bytes ?? 1;
    return item.copyWith(
      extractedRef: item.extractedRef?.copyWith(
        upload: item.extractedRef?.upload?.copyWith(
            latestEvent: UploadingEvent.progress,
            bytesSent: action.bytes,
            percent: action.bytes / totalBytes),
      ),
    );
  }).toList();

  return state.copyWith(
      detections: state.detections.copyWith(items: nextItems));
}

AppState _setUploadSucceeded(AppState state, ActionSetUploadSuccess action) {
  final List<DetectionItem> nextItems = state.detections.items
      .map<DetectionItem>((DetectionItem item) => (item.id == action.id)
          ? item.copyWith(
              extractedRef: item.extractedRef?.copyWith(
                  upload: item.extractedRef?.upload
                      ?.copyWith(latestEvent: UploadingEvent.success)))
          : item)
      .toList();

  return state.copyWith(
      detections: state.detections.copyWith(items: nextItems));
}

AppState _setDetectingProgress(
    AppState state, ActionSetDetectingProgress action) {
  final List<DetectionItem> nextItems = state.detections.items
      .map<DetectionItem>((DetectionItem item) => (item.id == action.id)
          ? item.copyWith(progress: action.progress, result: action.result)
          : item)
      .toList();

  return state.copyWith(
      detections: state.detections.copyWith(items: nextItems));
}

AppState _addProblem(AppState state, ActionAddProblem action) {
  // ignore: avoid_print
  print(action.problem);

  final List<Problem> newProblems =
      List<Problem>.unmodifiable([...state.problems, action.problem]);

  if (action.problem.type == ProblemType.imageUpload) {
    final problemId = action.problem.info?['id'];
    final List<DetectionItem> nextItems = state.detections.items
        .map<DetectionItem>((DetectionItem item) => (item.id == problemId)
            ? item.copyWith(
                extractedRef: item.extractedRef?.copyWith(
                    upload: item.extractedRef?.upload
                        ?.copyWith(latestEvent: UploadingEvent.failure)))
            : item)
        .toList();

    return state.copyWith(
        problems: newProblems,
        detections: state.detections.copyWith(items: nextItems));
  } else {
    return state.copyWith(problems: newProblems);
  }
}

AppState _removeProblem(AppState state, ActionRemoveProblem action) {
  final List<Problem> nextProblems = state.problems
      .where((Problem problem) => problem != action.problem)
      .toList();

  return state.copyWith(problems: nextProblems);
}
