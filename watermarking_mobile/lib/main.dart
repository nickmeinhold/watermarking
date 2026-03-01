import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';
import 'package:watermarking_mobile/middleware/api_middleware.dart';
import 'package:watermarking_mobile/services/mobile_device_service.dart';
import 'package:watermarking_mobile/views/app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Already initialized by google-services plugin
  }

  final AuthService authService = AuthService();
  final DatabaseService databaseService = DatabaseService();
  final StorageService storageService = StorageService();
  final DeviceService deviceService = MobileDeviceService();

  // REST API integration — mark/detect/delete go through the REST API.
  const apiUrl = String.fromEnvironment('WATERMARKING_API_URL',
      defaultValue: 'https://watermarking-api-78940960204.us-central1.run.app');

  final Store<AppState> store = Store<AppState>(appReducer,
      middleware: <Middleware<AppState>>[
        ...createApiMiddlewares(
          WatermarkingApiService(baseUrl: apiUrl),
        ),
        ...createMiddlewares(
            authService, databaseService, deviceService, storageService),
        createEpicMiddleware(authService, databaseService, storageService),
      ],
      initialState: AppState.initialState());

  runApp(MyApp(store));
}
