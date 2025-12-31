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
  TypedReducer<AppState, ActionSetAuthState>(_setAuthState).call,
  TypedReducer<AppState, ActionSetProfilePicUrl>(_setProfilePicUrl).call,
  TypedReducer<AppState, ActionSetOriginalImages>(_setOriginalImages).call,
  TypedReducer<AppState, ActionUpdateMarkedImages>(_updateMarkedImages).call,
  TypedReducer<AppState, ActionSetDetectionItems>(_setDetectionItems).call,
  TypedReducer<AppState, ActionSetBottomNav>(_setBottomNav).call,
  TypedReducer<AppState, ActionShowBottomSheet>(_setBottomSheet).call,
  TypedReducer<AppState, ActionSetSelectedImage>(_setSelectedImage).call,
  TypedReducer<AppState, ActionAddDetectionItem>(_addDetectionItem).call,
  TypedReducer<AppState, ActionStartUpload>(_setUploadStartTime).call,
  TypedReducer<AppState, ActionSetUploadProgress>(_setUploadProgress).call,
  TypedReducer<AppState, ActionSetUploadSuccess>(_setUploadSucceeded).call,
  TypedReducer<AppState, ActionSetDetectingProgress>(_setDetectingProgress)
      .call,
  TypedReducer<AppState, ActionAddProblem>(_addProblem).call,
  TypedReducer<AppState, ActionRemoveProblem>(_removeProblem).call,
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
              id: data['id']?.toString(),
              message: data['message']?.toString(),
              name: data['name']?.toString(),
              strength: (data['strength'] is num)
                  ? (data['strength'] as num).toInt()
                  : (data['strength'] is String
                      ? int.tryParse(data['strength'] as String)
                      : null),
              path: data['path']?.toString(),
              servingUrl: data['servingUrl']?.toString(),
              progress: data['progress']?.toString(),
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
              id: data['id']?.toString(),
              message: data['message']?.toString(),
              name: data['name']?.toString(),
              strength: (data['strength'] is num)
                  ? (data['strength'] as num).toInt()
                  : (data['strength'] is String
                      ? int.tryParse(data['strength'] as String)
                      : null),
              path: data['path']?.toString(),
              servingUrl: data['servingUrl']?.toString(),
              progress: data['progress']?.toString(),
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
  // Check if item exists
  final existingIndex =
      state.detections.items.indexWhere((item) => item.id == action.id);

  if (existingIndex == -1) {
    if (action.id.isEmpty) return state; // Don't add if empty ID (empty state)

    // Add new item if detecting started and not in list
    final newItem = DetectionItem(
      id: action.id,
      progress: action.progress,
      result: action.result,
      error: action.error,
      started: DateTime.now(),
      extractedRef: action.pathMarked != null
          ? ExtractedImageReference(remotePath: action.pathMarked)
          : null,
    );

    return state.copyWith(
        detections: state.detections
            .copyWith(items: [newItem, ...state.detections.items]));
  }

  // Update existing item
  final List<DetectionItem> nextItems = state.detections.items
      .map<DetectionItem>((DetectionItem item) => (item.id == action.id)
          ? item.copyWith(
              progress: action.progress,
              result: action.result,
              error: action.error,
              extractedRef: action.pathMarked != null
                  ? ExtractedImageReference(remotePath: action.pathMarked)
                  : item.extractedRef,
            )
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
