import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';
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
    widget.store.dispatch(const ActionObserveAuthState());
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
            home: StoreConnector<AppState, UserModel>(
                converter: (Store<AppState> store) => store.state.user,
                builder: (BuildContext context, UserModel user) {
                  return (user.waiting)
                      ? const Center(
                          child:
                              Text('Waiting', textDirection: TextDirection.ltr))
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
