import 'package:material_ui/material_ui.dart';

import '../../controllers/theme_controller.dart';
import 'painters.dart';
import 'settings_tiles.dart';
import 'style_illustration.dart';

/// Static palette data. Kept outside [build] so it is not recreated whenever
/// a theme value changes and the builder runs again.
const List<({AppThemeColor name, String label, List<Color> colors})> _palettes = [
  (
    name: AppThemeColor.emerald,
    label: 'Emerald',
    colors: [Color(0xFFA2E0A4), Color(0xFF1B5339), Color(0xFF78D6C6)],
  ),
  (
    name: AppThemeColor.blossom,
    label: 'Blossom',
    colors: [Color(0xFFF1B0E7), Color(0xFF532448), Color(0xFFF3B49F)],
  ),
  (
    name: AppThemeColor.ocean,
    label: 'Ocean',
    colors: [Color(0xFFACC3FC), Color(0xFF323B52), Color(0xFFDFBCF6)],
  ),
  (
    name: AppThemeColor.amber,
    label: 'Amber',
    colors: [Color(0xFFF9B983), Color(0xFF5E350C), Color(0xFFC7D36F)],
  ),
  (
    name: AppThemeColor.coral,
    label: 'Coral',
    colors: [Color(0xFFFFAAA6), Color(0xFF502C32), Color(0xFFE2C08D)],
  ),
];

const List<({AppThemeMode mode, String label})> _themeModes = [
  (mode: AppThemeMode.system, label: 'System'),
  (mode: AppThemeMode.light, label: 'Light'),
  (mode: AppThemeMode.dark, label: 'Dark'),
];

/// Style settings.
class StyleSettingsView extends StatelessWidget {
  final ThemeController themeController;

  const StyleSettingsView({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Style Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          themeController.mode,
          themeController.color,
          themeController.isAmoled,
          themeController.isDynamicSupported,
        ]),
        builder: (context, _) {
          final selectedMode = themeController.mode.value;
          final selectedColor = themeController.color.value;
          final isAmoledEnabled = themeController.isAmoled.value;
          final isDynamicSupported = themeController.isDynamicSupported.value;
          final dynamicThemeName = isDynamicSupported
              ? 'Dynamic Color Theme (Default)'
              : 'Pink Color Theme (Default)';

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StyleIllustration(
                  selectedPalette: selectedColor,
                  isDynamicSupported: isDynamicSupported,
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Accents & Schemes'),
              SettingsSection(
                children: [
                  SettingItem(
                    headlineText: dynamicThemeName,
                    supportingText: isDynamicSupported
                        ? 'Adaptive Android system theme'
                        : 'Default pink theme (dynamic color unavailable)',
                    leadingContent: const Icon(Icons.palette),
                    trailingContent: selectedColor == AppThemeColor.dynamic
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      themeController.updateThemeColor(AppThemeColor.dynamic);
                    },
                  ),
                  const SettingsSectionDivider(),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 16,
                      bottom: 20,
                      left: 16,
                      right: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final palette in _palettes)
                          _PaletteOption(
                            name: palette.name,
                            label: palette.label,
                            colors: palette.colors,
                            selectedPalette: selectedColor,
                            onTap: () {
                              themeController.updateThemeColor(palette.name);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SettingsSectionDivider(),
              const SectionTitle(title: 'Preferred Theme Mode'),
              SettingsSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        for (final (index, entry) in _themeModes.indexed) ...[
                          if (index > 0) const SizedBox(width: 10),
                          _ThemeButton(
                            label: entry.label,
                            isSelected: selectedMode == entry.mode,
                            onTap: () {
                              themeController.updateThemeMode(entry.mode);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SettingsSectionDivider(),
              const SectionTitle(title: 'Display Options'),
              SettingsSection(
                children: [
                  SettingItem(
                    headlineText: 'AMOLED Black Mode',
                    supportingText: 'Uses pitch-black background to save battery',
                    leadingContent: const Icon(Icons.dark_mode),
                    trailingContent: Switch(
                      value: isAmoledEnabled,
                      onChanged: (value) {
                        themeController.updateAmoled(value);
                      },
                    ),
                    onTap: () {
                      themeController.updateAmoled(!isAmoledEnabled);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _PaletteOption extends StatelessWidget {
  final AppThemeColor name;
  final String label;
  final List<Color> colors;
  final AppThemeColor selectedPalette;
  final VoidCallback onTap;

  const _PaletteOption({
    required this.name,
    required this.label,
    required this.colors,
    required this.selectedPalette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedPalette == name;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(38, 38),
                      painter: PaletteCirclePainter(
                        colors: colors,
                        isSelected: isSelected,
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: SizedBox(
        height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: isSelected
                ? colorScheme.primaryContainer
                : Colors.transparent,
            foregroundColor: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            side: isSelected
                ? BorderSide.none
                : BorderSide(color: colorScheme.surfaceContainerHighest),
          ),
          onPressed: onTap,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
