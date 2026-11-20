import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

enum AppThemeColor { dynamic, emerald, blossom, ocean, amber, coral }

class ThemeController {
  final ValueNotifier<AppThemeMode> mode = ValueNotifier(AppThemeMode.system);

  final ValueNotifier<AppThemeColor> color = ValueNotifier(
    AppThemeColor.dynamic,
  );

  final ValueNotifier<bool> isAmoled = ValueNotifier(false);

  final ValueNotifier<bool> isDynamicSupported = ValueNotifier(true);

  static const String _themeModeKey = 'theme_mode';
  static const String _themeColorKey = 'theme_color';
  static const String _amoledKey = 'amoled_mode';

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedModeIndex = prefs.getInt(_themeModeKey);

    if (savedModeIndex != null &&
        savedModeIndex >= 0 &&
        savedModeIndex < AppThemeMode.values.length) {
      mode.value = AppThemeMode.values[savedModeIndex];
    }

    final savedColorIndex = prefs.getInt(_themeColorKey);

    if (savedColorIndex != null &&
        savedColorIndex >= 0 &&
        savedColorIndex < AppThemeColor.values.length) {
      color.value = AppThemeColor.values[savedColorIndex];
    }

    isAmoled.value = prefs.getBool(_amoledKey) ?? false;

    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      final accentColor = await DynamicColorPlugin.getAccentColor();
      isDynamicSupported.value = (corePalette != null || accentColor != null);
    } catch (_) {}
  }

  Future<void> updateThemeMode(AppThemeMode newMode) async {
    mode.value = newMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, newMode.index);
  }

  Future<void> updateThemeColor(AppThemeColor newColor) async {
    color.value = newColor;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeColorKey, newColor.index);
  }

  Future<void> updateAmoled(bool enabled) async {
    isAmoled.value = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_amoledKey, enabled);
  }

  void dispose() {
    mode.dispose();
    color.dispose();
    isAmoled.dispose();
    isDynamicSupported.dispose();
  }
}
