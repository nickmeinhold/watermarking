import 'dart:developer' as developer;

import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

/// Creates middleware entries that intercept mark/detect/delete actions and
/// route them through the REST API instead of the legacy Firebase queue.
///
/// These middlewares do NOT call `next(action)`, which prevents the core
/// middleware from creating `tasks/{id}` documents. All state updates flow
/// through existing Firestore listeners.
///
/// For captured detection (camera -> upload -> detect), the core middleware
/// still handles ActionPerformExtraction, ActionProcessExtraction, and
/// ActionStartUpload. Only ActionSetUploadSuccess is intercepted here to
/// route detection through the API instead of creating a Firestore task.
List<Middleware<AppState>> createApiMiddlewares(
  WatermarkingApiService apiService,
  StorageService storageService,
) {
  return <Middleware<AppState>>[
    TypedMiddleware<AppState, ActionMarkImage>(
      _markImageViaApi(apiService),
    ).call,
    TypedMiddleware<AppState, ActionDetectMarkedImage>(
      _detectMarkedImageViaApi(apiService),
    ).call,
    TypedMiddleware<AppState, ActionSetUploadSuccess>(
      _startDetectionViaApi(apiService, storageService),
    ).call,
    TypedMiddleware<AppState, ActionDeleteOriginalImage>(
      _deleteOriginalViaApi(apiService),
    ).call,
    TypedMiddleware<AppState, ActionDeleteMarkedImage>(
      _deleteMarkedViaApi(apiService),
    ).call,
    TypedMiddleware<AppState, ActionDeleteDetectionItem>(
      _deleteDetectionViaApi(apiService),
    ).call,
  ];
}

/// Intercepts ActionMarkImage to process via REST API with GCS paths.
void Function(Store<AppState>, ActionMarkImage, NextDispatcher)
    _markImageViaApi(WatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action).
    try {
      await for (final event in apiService.watermarkImageGcs(
        originalImageId: action.imageId,
        imagePath: action.imagePath,
        imageName: action.imageName,
        message: action.message,
        strength: action.strength.round(),
      )) {
        if (event.containsKey('error')) {
          throw Exception(event['error']);
        }
      }
    } catch (error, trace) {
      developer.log('API marking error: $error',
          name: 'ApiMiddleware', error: error, stackTrace: trace);
      store.dispatch(ActionAddProblem(
        problem: Problem(
          type: ProblemType.marking,
          message: error.toString(),
          trace: trace,
        ),
      ));
    }
  };
}

/// Intercepts ActionDetectMarkedImage (pre-marked detection) to process via API.
void Function(Store<AppState>, ActionDetectMarkedImage, NextDispatcher)
    _detectMarkedImageViaApi(WatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action).
    try {
      await for (final event in apiService.detectWatermarkGcs(
        originalPath: action.originalPath,
        markedPath: action.markedPath,
        markedImageId: action.markedImageId,
      )) {
        if (event.containsKey('error')) {
          throw Exception(event['error']);
        }
      }
    } catch (error, trace) {
      developer.log('API detection error: $error',
          name: 'ApiMiddleware', error: error, stackTrace: trace);
      store.dispatch(ActionAddProblem(
        problem: Problem(
          type: ProblemType.detection,
          message: error.toString(),
          trace: trace,
        ),
      ));
    }
  };
}

/// Intercepts ActionSetUploadSuccess (captured detection flow).
/// After mobile uploads a captured image to GCS, this calls the API
/// with both GCS paths instead of creating a Firestore task.
void Function(Store<AppState>, ActionSetUploadSuccess, NextDispatcher)
    _startDetectionViaApi(
  WatermarkingApiService apiService,
  StorageService storageService,
) {
  return (store, action, next) async {
    // Still call next so the reducer updates upload state
    next(action);

    try {
      final selectedImagePath = store.state.originals.selectedImage?.filePath;
      if (selectedImagePath == null) return;

      final markedPath =
          'detecting-images/${store.state.user.id}/${action.id}';

      await for (final event in apiService.detectWatermarkGcs(
        originalPath: selectedImagePath,
        markedPath: markedPath,
        markedImageId: action.id,
      )) {
        if (event.containsKey('error')) {
          throw Exception(event['error']);
        }
      }
    } catch (error, trace) {
      developer.log('API captured detection error: $error',
          name: 'ApiMiddleware', error: error, stackTrace: trace);
      store.dispatch(ActionAddProblem(
        problem: Problem(
          type: ProblemType.detection,
          message: error.toString(),
          trace: trace,
        ),
      ));
    }
  };
}

/// Intercepts ActionDeleteOriginalImage.
void Function(Store<AppState>, ActionDeleteOriginalImage, NextDispatcher)
    _deleteOriginalViaApi(WatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action).
    try {
      await apiService.deleteOriginal(action.originalImageId);
    } catch (error, trace) {
      developer.log('API delete original error: $error',
          name: 'ApiMiddleware', error: error, stackTrace: trace);
      store.dispatch(ActionAddProblem(
        problem: Problem(
          type: ProblemType.images,
          message: error.toString(),
          trace: trace,
        ),
      ));
    }
  };
}

/// Intercepts ActionDeleteMarkedImage.
void Function(Store<AppState>, ActionDeleteMarkedImage, NextDispatcher)
    _deleteMarkedViaApi(WatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action).
    try {
      await apiService.deleteMarked(action.markedImageId);
    } catch (error, trace) {
      developer.log('API delete marked error: $error',
          name: 'ApiMiddleware', error: error, stackTrace: trace);
      store.dispatch(ActionAddProblem(
        problem: Problem(
          type: ProblemType.images,
          message: error.toString(),
          trace: trace,
        ),
      ));
    }
  };
}

/// Intercepts ActionDeleteDetectionItem.
void Function(Store<AppState>, ActionDeleteDetectionItem, NextDispatcher)
    _deleteDetectionViaApi(WatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action).
    try {
      await apiService.deleteDetection(action.detectionItemId);
    } catch (error, trace) {
      developer.log('API delete detection error: $error',
          name: 'ApiMiddleware', error: error, stackTrace: trace);
      store.dispatch(ActionAddProblem(
        problem: Problem(
          type: ProblemType.detection,
          message: error.toString(),
          trace: trace,
        ),
      ));
    }
  };
}
