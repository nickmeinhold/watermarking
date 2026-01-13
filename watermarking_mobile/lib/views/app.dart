import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';
import 'package:watermarking_mobile/main.dart' show kBypassAuth;
import 'package:watermarking_mobile/views/account_button.dart';
import 'package:watermarking_mobile/views/home_page.dart';
import 'package:watermarking_mobile/views/problems_observer.dart';
import 'package:watermarking_mobile/views/profile_page.dart';
import 'package:watermarking_mobile/views/select_image_observer.dart';
import 'package:watermarking_mobile/views/signin_page.dart';

class MyApp extends StatefulWidget {
  const MyApp(this.store, {super.key});

  final Store<AppState> store;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    if (!kBypassAuth) {
      widget.store.dispatch(const ActionObserveAuthState());
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
        store: widget.store,
        child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
            ),
            home: kBypassAuth
                ? const AppWidget()
                : StoreConnector<AppState, UserModel>(
                    converter: (Store<AppState> store) => store.state.user,
                    builder: (BuildContext context, UserModel user) {
                      return (user.waiting)
                          ? const Center(
                              child: Text('Waiting',
                                  textDirection: TextDirection.ltr))
                          : (user.id == null)
                              ? const SigninPage()
                              : const AppWidget();
                    })));
  }
}

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Use simplified UI in test/bypass mode
    if (kBypassAuth) {
      return const TestModeAppWidget();
    }

    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset(
          'assets/dw_logo_white.svg',
          height: 100.0,
          fit: BoxFit.cover,
        ),
        actions: <Widget>[
          AccountButton(key: const Key('AccountButton')),
          SelectImageObserver(),
          ProblemsObserver(),
        ],
      ),
      body: StoreConnector<AppState, int>(
          converter: (Store<AppState> store) => store.state.bottomNav.index,
          builder: (BuildContext context, int index) {
            return (index == 0) ? const HomePage() : const ProfilePage();
          }),
      bottomNavigationBar: StoreConnector<AppState, int>(
          converter: (Store<AppState> store) => store.state.bottomNav.index,
          builder: (BuildContext context, int index) {
            return BottomNavigationBar(
              currentIndex: index,
              onTap: (int index) {
                final action = (index == 1)
                    ? ActionShowBottomSheet(show: true)
                    : ActionSetBottomNav(index: index);
                StoreProvider.of<AppState>(context).dispatch(action);
              },
              type: BottomNavigationBarType.fixed,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home, key: Key('HomeTabIcon')),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: StoreConnector<AppState, OriginalImageReference?>(
                      converter: (Store<AppState> store) =>
                          store.state.originals.selectedImage,
                      builder: (BuildContext context,
                          OriginalImageReference? imageRef) {
                        return SizedBox(
                          width: 50,
                          height: 50,
                          child: (imageRef?.url == null)
                              ? const Icon(Icons.touch_app,
                                  key: Key('ImageTabIcon'))
                              : Image.network(
                                  imageRef!.url!,
                                  key: const Key('ImageTabImage'),
                                ),
                        );
                      }),
                  label: '',
                ),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.person, key: Key('ProfileTabIcon')),
                    label: 'Profile'),
              ],
            );
          }),
      floatingActionButton: StoreConnector<AppState, OriginalImagesViewModel>(
        converter: (Store<AppState> store) => store.state.originals,
        builder: (BuildContext context, OriginalImagesViewModel viewModel) {
          if (viewModel.selectedImage == null) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            key: const Key('ScanFAB'),
            onPressed: () {
              StoreProvider.of<AppState>(context).dispatch(
                  ActionPerformExtraction(
                      width: viewModel.selectedWidth ?? 512,
                      height: viewModel.selectedHeight ?? 512));
            },
            tooltip: 'Scan',
            child: const Icon(Icons.search),
          );
        },
      ),
    );
  }
}

/// Simplified app widget for test/development mode without Firebase
class TestModeAppWidget extends StatefulWidget {
  const TestModeAppWidget({super.key});

  @override
  State<TestModeAppWidget> createState() => _TestModeAppWidgetState();
}

class _TestModeAppWidgetState extends State<TestModeAppWidget> {
  final List<DetectionResultLocal> _detectionResults = [];
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watermark Detection'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : () => _startDetection(context),
        icon: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt),
        label: Text(_isProcessing ? 'Processing...' : 'Detect Watermark'),
        backgroundColor: _isProcessing ? colorScheme.surfaceContainerHighest : null,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_detectionResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_search,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No detections yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to select an image\nand detect watermarks',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _detectionResults.length,
      itemBuilder: (context, index) {
        final result = _detectionResults[_detectionResults.length - 1 - index];
        return _DetectionResultCard(result: result);
      },
    );
  }

  Future<void> _startDetection(BuildContext context) async {
    setState(() => _isProcessing = true);

    try {
      const channel = MethodChannel('watermarking.enspyr.co/detect');
      final result = await channel.invokeMethod('startDetection', {'useMock': true});

      if (result != null && mounted) {
        setState(() {
          _detectionResults.add(DetectionResultLocal(
            filePath: result as String,
            timestamp: DateTime.now(),
            success: true,
          ));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Detection completed!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().contains('CANCELLED')
            ? 'Selection cancelled'
            : 'Detection failed: $e';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Mode'),
        content: const Text(
          'This app is running in test mode with mock detection.\n\n'
          '• Tap "Detect Watermark" to select an image\n'
          '• The mock detector will process it\n'
          '• Results are stored locally (not in Firebase)\n\n'
          'To use real OpenCV detection, set USE_MOCK_DETECTION = false in MainActivity.kt',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Local detection result (not persisted to Firebase)
class DetectionResultLocal {
  final String filePath;
  final DateTime timestamp;
  final bool success;
  final String? error;

  DetectionResultLocal({
    required this.filePath,
    required this.timestamp,
    required this.success,
    this.error,
  });
}

/// Card widget to display a detection result
class _DetectionResultCard extends StatelessWidget {
  final DetectionResultLocal result;

  const _DetectionResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final file = File(result.filePath);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: file.existsSync()
                ? Image.file(
                    file,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      result.success ? Icons.check_circle : Icons.error,
                      color: result.success ? Colors.green : colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      result.success ? 'Detection Successful' : 'Detection Failed',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTimestamp(result.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.filePath.split('/').last,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
