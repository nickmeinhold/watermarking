import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

import '../services/watermarking_api_service.dart';

/// Creates middleware entries that intercept mark/detect/delete actions and
/// route them through the REST API instead of the legacy Firebase queue.
///
/// These middlewares do NOT call `next(action)`, which prevents the core
/// middleware from creating `tasks/{id}` documents. All state updates flow
/// through existing Firestore listeners.
///
/// Note: Unlike mobile, web does not handle `ActionSetUploadSuccess` because
/// web has no camera capture flow — detection is only triggered via
/// `ActionDetectMarkedImage` from the UI.
List<Middleware<AppState>> createApiMiddlewares(
  WebWatermarkingApiService apiService,
) {
  return <Middleware<AppState>>[
    TypedMiddleware<AppState, ActionMarkImage>(
      _markImageViaApi(apiService),
    ).call,
    TypedMiddleware<AppState, ActionDetectMarkedImage>(
      _detectMarkedImageViaApi(apiService),
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

/// Get a fresh Firebase Auth ID token and set it on the API service.
Future<void> _refreshToken(WebWatermarkingApiService apiService) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');
  apiService.idToken = await user.getIdToken();
}

/// Intercepts ActionMarkImage to process via REST API with GCS paths.
/// Server downloads from GCS, processes, uploads result, writes Firestore.
/// Client just sends GCS path — no image bytes transit the browser.
void Function(Store<AppState>, ActionMarkImage, NextDispatcher)
    _markImageViaApi(WebWatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action) — prevents core middleware from creating a task doc.
    try {
      await _refreshToken(apiService);

      // Stream SSE progress — server handles everything (GCS download, C++,
      // GCS upload, Firestore write). We just listen for errors.
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
        // Progress and final Firestore writes are handled server-side.
        // Existing Firestore listeners will pick up markedImages changes.
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

/// Intercepts ActionDetectMarkedImage to process via REST API with GCS paths.
/// Server downloads both images from GCS, runs detection, writes results to Firestore.
void Function(Store<AppState>, ActionDetectMarkedImage, NextDispatcher)
    _detectMarkedImageViaApi(WebWatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action) — prevents core middleware from creating a task doc.
    try {
      await _refreshToken(apiService);

      await for (final event in apiService.detectWatermarkGcs(
        originalPath: action.originalPath,
        markedPath: action.markedPath,
        markedImageId: action.markedImageId,
      )) {
        if (event.containsKey('error')) {
          throw Exception(event['error']);
        }
        // Server writes detectionItems doc. Existing Firestore listener picks it up.
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

/// Intercepts ActionDeleteOriginalImage — calls API instead of creating a task doc.
void Function(Store<AppState>, ActionDeleteOriginalImage, NextDispatcher)
    _deleteOriginalViaApi(WebWatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action).
    try {
      await _refreshToken(apiService);
      await apiService.deleteOriginal(action.originalImageId);
      // Firestore listeners will pick up the deletion.
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

/// Intercepts ActionDeleteMarkedImage — calls API instead of creating a task doc.
void Function(Store<AppState>, ActionDeleteMarkedImage, NextDispatcher)
    _deleteMarkedViaApi(WebWatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action).
    try {
      await _refreshToken(apiService);
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

/// Intercepts ActionDeleteDetectionItem — calls API instead of creating a task doc.
void Function(Store<AppState>, ActionDeleteDetectionItem, NextDispatcher)
    _deleteDetectionViaApi(WebWatermarkingApiService apiService) {
  return (store, action, next) async {
    // Do NOT call next(action).
    try {
      await _refreshToken(apiService);
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
