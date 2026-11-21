/// The landing screen for Photo Resizer.
///
/// Combines the welcome UI with image picking and direct route navigation
/// to [ConfigureScreen].
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../controllers/photo_controller.dart';
import '../controllers/theme_controller.dart';
import '../widgets/route_scope.dart';
import 'configure_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeController? themeController;

  const HomeScreen({super.key, this.themeController});

  static const String routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PhotoController _controller = PhotoController();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          themeController: widget.themeController ?? ThemeController(),
        ),
      ),
    );
  }

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
      if (!mounted) return;
      if (_controller.originalMetadata != null) {
        Navigator.of(context).push(
          ConfigureScreen.route(
            controller: _controller,
            themeController: widget.themeController,
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return RouteScope(
      controller: _controller,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.primaryContainer,
                colors.surfaceContainer,
                colors.surface,
              ],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  Icon(Icons.crop_rounded, size: 24, color: colors.primary),
                  const SizedBox(width: 10),
                  const Text(
                    'Photo Resizer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  key: const Key('settings_button'),
                  tooltip: 'Open Settings',
                  icon: Icon(Icons.settings, color: colors.primary),
                  onPressed: _openSettings,
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: _availableHeight(context),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Asymmetric radial glow around the logo card.
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colors.primary.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.2),
                              ),
                              boxShadow: const [
                                BoxShadow(color: Color(0x22000000), blurRadius: 8),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.crop_rounded,
                                size: 44,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Resize, crop, and compress metadata to fit any target dimensions and KB files instantly. Clean client-side rendering.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          key: const Key('gallery_button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => _pick(ImageSource.gallery),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'Select Photo from Gallery',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          key: const Key('camera_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(
                              color: colors.primary.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => _pick(ImageSource.camera),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'Take Photo with Camera',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _availableHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    return (media.size.height - media.padding.top - media.padding.bottom - kToolbarHeight)
        .clamp(0.0, double.infinity)
        .toDouble();
  }
}
