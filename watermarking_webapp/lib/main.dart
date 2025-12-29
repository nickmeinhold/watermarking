import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';
import 'package:watermarking_webapp/services/web_device_service.dart';
import 'package:watermarking_webapp/views/admin_page.dart';
import 'package:watermarking_webapp/views/detect_page.dart';
import 'package:watermarking_webapp/views/marked_images_page.dart';
import 'package:watermarking_webapp/views/opening_page.dart';
import 'package:watermarking_webapp/views/original_images_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final AuthService authService = AuthService();
  final DatabaseService databaseService = DatabaseService();
  final StorageService storageService = StorageService();
  final DeviceService deviceService = WebDeviceService();

  final Store<AppState> store = Store<AppState>(appReducer,
      middleware: <Middleware<AppState>>[
        ...createMiddlewares(
            authService, databaseService, deviceService, storageService),
        createEpicMiddleware(authService, databaseService, storageService).call,
      ],
      initialState: AppState.initialState());

  runApp(WatermarkingApp(store: store));
}

class WatermarkingApp extends StatefulWidget {
  const WatermarkingApp({super.key, required this.store});

  final Store<AppState> store;

  @override
  State<WatermarkingApp> createState() => _WatermarkingAppState();
}

class _WatermarkingAppState extends State<WatermarkingApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    widget.store.dispatch(const ActionObserveAuthState());

    _router = GoRouter(
      initialLocation: '/opening',
      redirect: (context, state) {
        final user = widget.store.state.user;
        final isLoggedIn = user.id != null;
        final isOnOpeningPage = state.matchedLocation == '/opening';

        // If not logged in and not on opening page, redirect to opening
        if (!isLoggedIn && !isOnOpeningPage) {
          return '/opening';
        }

        // If logged in and on opening page, redirect to originals
        if (isLoggedIn && isOnOpeningPage) {
          return '/original';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/opening',
          builder: (context, state) => const OpeningPage(),
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/original',
              builder: (context, state) => const OriginalImagesPage(),
            ),
            GoRoute(
              path: '/marked',
              builder: (context, state) => const MarkedImagesPage(),
            ),
            GoRoute(
              path: '/detect',
              builder: (context, state) => const DetectPage(),
            ),
            GoRoute(
              path: '/admin',
              builder: (context, state) => const AdminPage(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: widget.store,
      child: StoreConnector<AppState, UserModel>(
        converter: (store) => store.state.user,
        builder: (context, user) {
          // Force router refresh when auth state changes
          _router.refresh();
          return MaterialApp.router(
            title: 'Watermarking',
            theme: ThemeData(
              primaryColor: Colors.amber,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
              useMaterial3: true,
            ),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watermarking'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          StoreConnector<AppState, UserModel>(
            converter: (store) => store.state.user,
            builder: (context, user) {
              if (user.photoUrl != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      StoreProvider.of<AppState>(context)
                          .dispatch(ActionSignout());
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(user.photoUrl!),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
              child: const Text(
                'Watermarking',
                style: TextStyle(fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Original Images'),
              onTap: () {
                Navigator.pop(context);
                context.go('/original');
              },
            ),
            ListTile(
              leading: const Icon(Icons.water_drop),
              title: const Text('Marked Images'),
              onTap: () {
                Navigator.pop(context);
                context.go('/marked');
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Detect'),
              onTap: () {
                Navigator.pop(context);
                context.go('/detect');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Admin'),
              onTap: () {
                Navigator.pop(context);
                context.go('/admin');
              },
            ),
          ],
        ),
      ),
      body: child,
    );
  }
}
