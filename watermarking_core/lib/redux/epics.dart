import 'package:redux_epics/redux_epics.dart';
import 'package:rxdart/rxdart.dart';
import 'package:watermarking_core/models/app_state.dart';
import 'package:watermarking_core/redux/actions.dart';
import 'package:watermarking_core/services/auth_service.dart';
import 'package:watermarking_core/services/database_service.dart';
import 'package:watermarking_core/services/storage_service.dart';

EpicMiddleware<AppState> createEpicMiddleware(AuthService authService,
    DatabaseService databaseService, StorageService uploadService) {
  final Epic<AppState> epic = combineEpics<AppState>(<Epic<AppState>>[
    createAuthEpic(authService),
    createUploadEpic(databaseService, uploadService),
  ]);

  return EpicMiddleware<AppState>(epic);
}

Epic<AppState> createUploadEpic(
    DatabaseService databaseService, StorageService service) {
  return (Stream<dynamic> actions, EpicStore<AppState> store) {
    return actions
        .where((dynamic action) => action is ActionStartUpload)
        .cast<ActionStartUpload>()
        .flatMap((ActionStartUpload action) {
      return service.startUpload(entryId: action.id, filePath: action.filePath);
    });
  };
}

Epic<AppState> createAuthEpic(AuthService service) {
  return (Stream<dynamic> actions, EpicStore<AppState> store) {
    return actions
        .where((dynamic action) => action is ActionObserveAuthState)
        .cast<ActionObserveAuthState>()
        .flatMap((ActionObserveAuthState action) {
      return service.listenToAuthState();
    });
  };
}
