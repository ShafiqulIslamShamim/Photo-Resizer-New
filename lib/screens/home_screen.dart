/// Port of `MainActivity.kt` / `PhotoResizerApp`.
///
/// Navigation is handled with real routes (`MaterialPageRoute` inside a local
/// Navigator). The controller's [ScreenState] only acts as the trigger for a
/// route push/pop, so each screen stays an independent route in the stack.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/photo_controller.dart';
import '../controllers/theme_controller.dart';
import 'configure_screen.dart';
import 'cropping_screen.dart';
import 'preview_screen.dart';
import 'settings/settings_screen.dart';
import 'welcome_screen.dart';

const String kWelcomeRoute = '/';
const String kConfigureRoute = '/configure';
const String kCroppingRoute = '/cropping';
const String kPreviewRoute = '/preview';

const List<ScreenState> _routeOrder = [
  ScreenState.welcome,
  ScreenState.configure,
  ScreenState.cropping,
  ScreenState.preview,
];

class HomeScreen extends StatefulWidget {
  /// Kept for parity with the existing theme/settings layer in `main.dart`.
  final ThemeController? themeController;

  const HomeScreen({super.key, this.themeController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PhotoController _controller = PhotoController();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final _RouteWatcher _routeWatcher;
  String _currentRoute = kWelcomeRoute;

  @override
  void initState() {
    super.initState();
    _routeWatcher = _RouteWatcher(_onRouteChanged);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Controller -> route translation
  // ---------------------------------------------------------------------------
  void _onControllerChanged() {
    if (!mounted) return;
    final message = _controller.transientMessage;
    final target = _controller.screenState;

    // Defer navigation until after the current build/layout pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (message != null) {
        _controller.clearTransientMessage();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      _navigateTo(target);
    });
  }

  void _onRouteChanged(String? name) {
    final route = name ?? kWelcomeRoute;
    _currentRoute = route;
    // System-back pops happen outside the controller: keep both in sync.
    _controller.syncScreenState(_stateForRoute(route));
  }

  void _navigateTo(ScreenState target) {
    final targetRoute = _routeName(target);
    if (targetRoute == _currentRoute) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final targetIndex = _routeOrder.indexOf(target);
    final currentIndex = _routeOrder.indexOf(_stateForRoute(_currentRoute));

    if (targetIndex > currentIndex) {
      navigator.push(
        MaterialPageRoute<dynamic>(
          settings: RouteSettings(name: targetRoute),
          builder: (_) => _RouteScope(
            controller: _controller,
            child: _screenFor(target),
          ),
        ),
      );
    } else {
      navigator.popUntil(ModalRoute.withName(targetRoute));
    }
    _currentRoute = targetRoute;
  }

  // ---------------------------------------------------------------------------
  // Route helpers
  // ---------------------------------------------------------------------------
  static String _routeName(ScreenState state) => switch (state) {
        ScreenState.welcome => kWelcomeRoute,
        ScreenState.configure => kConfigureRoute,
        ScreenState.cropping => kCroppingRoute,
        ScreenState.preview => kPreviewRoute,
      };

  static ScreenState _stateForRoute(String route) => switch (route) {
        kConfigureRoute => ScreenState.configure,
        kCroppingRoute => ScreenState.cropping,
        kPreviewRoute => ScreenState.preview,
        _ => ScreenState.welcome,
      };

  void _openSettings() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          themeController: widget.themeController ?? ThemeController(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Picking
  // ---------------------------------------------------------------------------
  Future<void> _pick(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _controller.setImage(
        bytes: bytes,
        name: file.name,
        path: file.path,
        mimeType: file.mimeType,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Camera is not available on this device or platform'
                : 'Failed to pick image: ${e.toString()}',
          ),
        ),
      );
    }
  }

  Widget _screenFor(ScreenState state) {
    switch (state) {
      case ScreenState.welcome:
        return WelcomeScreen(
          onGalleryClick: () => _pick(ImageSource.gallery),
          onCameraClick: () => _pick(ImageSource.camera),
          onSettingsClick: _openSettings,
        );
      case ScreenState.configure:
        return ConfigureScreen(
          controller: _controller,
          onBack: _controller.reset,
          onSettingsClick: _openSettings,
        );
      case ScreenState.cropping:
        return CroppingScreen(
          controller: _controller,
          onSettingsClick: _openSettings,
        );
      case ScreenState.preview:
        return PreviewScreen(
          controller: _controller,
          onSettingsClick: _openSettings,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      observers: [_routeWatcher],
      initialRoute: kWelcomeRoute,
      onGenerateRoute: (settings) {
        final state = _stateForRoute(settings.name ?? kWelcomeRoute);
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => _RouteScope(
            controller: _controller,
            child: _screenFor(state),
          ),
        );
      },
    );
  }
}

/// Tracks which nested route is on top so controller state and the route stack
/// never drift apart (important when the hardware/system back button is used).
class _RouteWatcher extends RouteObserver<PageRoute<dynamic>> {
  final ValueChanged<String?> onRouteChanged;

  _RouteWatcher(this.onRouteChanged);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onRouteChanged(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onRouteChanged(previousRoute?.settings.name ?? kWelcomeRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    onRouteChanged(previousRoute?.settings.name ?? kWelcomeRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onRouteChanged(newRoute?.settings.name ?? kWelcomeRoute);
  }
}

/// Common chrome for every route: loading spinner and out-of-memory dialog.
class _RouteScope extends StatelessWidget {
  final PhotoController controller;
  final Widget child;

  const _RouteScope({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Stack(
          children: [
            child,
            if (controller.oomDialogMessage != null)
              Center(
                child: AlertDialog(
                  icon: Icon(
                    Icons.warning,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text(
                    'Device Memory Limit Reached',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  content: Text(
                    controller.oomDialogMessage!,
                    style: const TextStyle(fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      onPressed: controller.dismissOomDialog,
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            if (controller.loading) _loadingOverlay(context),
          ],
        );
      },
    );
  }

  Widget _loadingOverlay(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Card(
              color: colors.surface,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Optimizing Image Quality',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Running direct iterations to target exact limits.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
