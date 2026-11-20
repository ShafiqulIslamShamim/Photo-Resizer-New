import 'package:material_ui/material_ui.dart';

import '../../controllers/theme_controller.dart';
import 'painters.dart';

/// Palette illustration.
class StyleIllustration extends StatelessWidget {
  final AppThemeColor selectedPalette;
  final bool isDynamicSupported;

  const StyleIllustration({
    super.key,
    required this.selectedPalette,
    this.isDynamicSupported = true,
  });

  String activeLabel() {
    switch (selectedPalette) {
      case AppThemeColor.emerald:
        return 'Emerald Active';
      case AppThemeColor.blossom:
        return 'Blossom Active';
      case AppThemeColor.ocean:
        return 'Ocean Active';
      case AppThemeColor.amber:
        return 'Amber Active';
      case AppThemeColor.coral:
        return 'Coral Active';
      case AppThemeColor.dynamic:
        return isDynamicSupported ? 'Dynamic Active' : 'Pink Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomPaint(
              size: Size.infinite,
              painter: VectorIllustrationPainter(colorScheme: colorScheme),
            ),
          ),
          Positioned(
            left: 4,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.palette, color: colorScheme.primary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    activeLabel(),
                    style: TextStyle(
                      color: colorScheme.onSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
