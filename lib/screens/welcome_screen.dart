/// Port of `WelcomeScreen.kt` — the landing screen.
import 'package:material_ui/material_ui.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGalleryClick;
  final VoidCallback onCameraClick;
  final VoidCallback onSettingsClick;

  const WelcomeScreen({
    super.key,
    required this.onGalleryClick,
    required this.onCameraClick,
    required this.onSettingsClick,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primaryContainer, colors.surfaceContainer, colors.surface],
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
                onPressed: onSettingsClick,
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
                          colors: [colors.primary.withValues(alpha: 0.15), Colors.transparent],
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
                        onPressed: onGalleryClick,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.photo_library, size: 20),
                            const SizedBox(width: 12),
                            const Text(
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
                        onPressed: onCameraClick,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt, size: 20),
                            const SizedBox(width: 12),
                            const Text(
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
    );
  }

  double _availableHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    return (media.size.height - media.padding.top - media.padding.bottom - kToolbarHeight)
        .clamp(0.0, double.infinity)
        .toDouble();
  }
}
