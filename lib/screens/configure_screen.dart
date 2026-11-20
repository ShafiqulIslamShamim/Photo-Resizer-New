/// Port of `ConfigureScreen.kt` — dimension, preset, shape and size-limit setup.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/photo_controller.dart';
import '../models/photo_models.dart';
import '../util/image_utils.dart';
import '../widgets/app_bar_circle_button.dart';

class ConfigureScreen extends StatefulWidget {
  final PhotoController controller;
  final VoidCallback onBack;
  final VoidCallback onSettingsClick;

  const ConfigureScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onSettingsClick,
  });

  @override
  State<ConfigureScreen> createState() => _ConfigureScreenState();
}

class _ConfigureScreenState extends State<ConfigureScreen> {
  String _segment = 'Custom Size';

  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _mmWidthCtrl = TextEditingController();
  final _mmHeightCtrl = TextEditingController();
  final _ratioWidthCtrl = TextEditingController();
  final _ratioHeightCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _widthCtrl,
      _heightCtrl,
      _mmWidthCtrl,
      _mmHeightCtrl,
      _ratioWidthCtrl,
      _ratioHeightCtrl,
      _limitCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync(TextEditingController c, String value) {
    if (c.text != value) {
      final selection = c.selection;
      c.text = value;
      c.selection = selection;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        _sync(_widthCtrl, c.targetWidthInput);
        _sync(_heightCtrl, c.targetHeightInput);
        _sync(_mmWidthCtrl, c.customMmWidth);
        _sync(_mmHeightCtrl, c.customMmHeight);
        _sync(_ratioWidthCtrl, c.customRatioWidth);
        _sync(_ratioHeightCtrl, c.customRatioHeight);
        _sync(_limitCtrl, c.sizeLimitInput);

        final meta = c.originalMetadata;
        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: AppBarCircleButton(
              icon: Icons.arrow_back,
              tooltip: 'Navigate back',
              buttonKey: const Key('back_button'),
              colorScheme: colors,
              onPressed: widget.onBack,
            ),
            title: const Text(
              'Resize Preferences',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            actions: [
              AppBarCircleButton(
                icon: Icons.settings,
                tooltip: 'Settings',
                colorScheme: colors,
                onPressed: widget.onSettingsClick,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: meta == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _previewCard(meta, c, colors),
                      const SizedBox(height: 4),
                      _sectionTitle('Resolution Mode'),
                      _segmented(
                        ['Custom Size', 'Preset Size', 'Aspect Ratio'],
                        _segment,
                        (value) {
                          setState(() => _segment = value);
                          if (value == 'Aspect Ratio') {
                            c.selectPreset(c.selectedPresetRatio);
                          } else if (value == 'Preset Size' &&
                              c.selectedPresetSize != 'None') {
                            c.selectPresetSize(c.selectedPresetSize);
                          }
                        },
                        colors,
                      ),
                      const SizedBox(height: 4),
                      switch (_segment) {
                        'Custom Size' => _customSize(c, colors),
                        'Preset Size' => _presetSize(c, colors),
                        'Aspect Ratio' => _aspectRatio(c, colors),
                        _ => const SizedBox.shrink(),
                      },
                      _sectionTitle('Image Cut Shape', top: 8),
                      _segmented(
                        ['Square', 'Circle', 'Triangle'],
                        c.selectedCutShape.label,
                        (value) => c.setCutShape(CutShapeX.fromLabel(value)),
                        colors,
                        testPrefix: 'shape_segment',
                      ),
                      _sectionTitle('File Size Optimization'),
                      _compressionCard(c, colors),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  Widget _previewCard(ImageMetadata meta, PhotoController c, ColorScheme colors) {
    return Card(
      color: colors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 180,
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.05),
                child: c.originalDisplayBytes == null
                    ? const SizedBox.shrink()
                    : Image.memory(
                        c.originalDisplayBytes!,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Original Image Metadata',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _metaColumn('Original Format', meta.format.label, colors),
                _metaColumn('Resolution', '${meta.width} × ${meta.height} px', colors),
                _metaColumn(
                  'Ratio',
                  ImageUtils.getAspectRatioText(meta.width, meta.height),
                  colors,
                ),
                _metaColumn(
                  'File Size',
                  ImageUtils.formatFileSize(meta.sizeBytes),
                  colors,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaColumn(String label, String value, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _sectionTitle(String text, {double top = 8}) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Shared surface used by every segmented control on this screen.
  Widget _segmentPanel({
    required List<Widget> children,
    required ColorScheme colors,
    double bottomMargin = 16,
    double radius = 14,
    double backgroundOpacity = 0.4,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: backgroundOpacity),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(children: children),
    );
  }

  Widget _segmented(
    List<String> options,
    String selected,
    ValueChanged<String> onChanged,
    ColorScheme colors, {
    String? testPrefix,
  }) {
    return _segmentPanel(
      colors: colors,
      children: [
        for (final option in options)
          Expanded(
            child: _tapBox(
              height: 40,
              selected: selected == option,
              colors: colors,
              onTap: () => onChanged(option),
              testKey: testPrefix == null ? null : '${testPrefix}_${option.toLowerCase()}',
              child: Text(
                option,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected == option ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tapBox({
    required double height,
    required bool selected,
    required ColorScheme colors,
    required VoidCallback onTap,
    required Widget child,
    String? testKey,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 4),
  }) {
    return SizedBox(
      height: height,
      child: InkWell(
        key: testKey == null ? null : Key(testKey),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required ColorScheme colors,
    required ValueChanged<String> onChanged,
    String? testKey,
    String? placeholder,
    bool allowDecimal = false,
  }) {
    return Expanded(
      child: TextField(
        key: testKey == null ? null : Key(testKey),
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        inputFormatters: [
          allowDecimal ? _DecimalTextFormatter() : FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: colors.primary),
          ),
          fillColor: colors.surface,
        ),
      ),
    );
  }

  Widget _customSize(PhotoController c, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Override Target Resolution (Pixels)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _field(
              controller: _widthCtrl,
              label: 'Width (px)',
              colors: colors,
              testKey: 'target_width_field',
              onChanged: c.setTargetWidth,
            ),
            const SizedBox(width: 16),
            _field(
              controller: _heightCtrl,
              label: 'Height (px)',
              colors: colors,
              testKey: 'target_height_field',
              onChanged: c.setTargetHeight,
            ),
          ],
        ),
      ],
    );
  }

  Widget _presetSize(PhotoController c, ColorScheme colors) {
    final presets = [
      ...kSizePresets.keys,
      kCustomPreset,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Standard Document Preset Sizes',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _chipWrap(
          presets,
          c.selectedPresetSize,
          colors,
          (preset) => c.selectPresetSize(preset),
        ),
        if (c.selectedPresetSize != 'None') ...[
          const SizedBox(height: 8),
          const Text(
            'Preset Resolution Mode',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _segmented(
            ['Maximum', 'Original'],
            c.presetResolutionMode.label,
            (v) => c.changePresetResolutionMode(
              v == 'Maximum'
                  ? PresetResolutionMode.maximum
                  : PresetResolutionMode.original,
            ),
            colors,
          ),
          _infoRow(
            c.presetResolutionMode == PresetResolutionMode.maximum
                ? 'Maximum Resolution retains the full pixel detail of your image. Only the aspect ratio is adjusted to match the preset, so the image quality is never downgraded.'
                : 'Original Preset Size rescales and shrinks the image down to match both the exact aspect ratio and dimensions of the preset (e.g., 295 × 354 px).',
            colors,
          ),
        ],
        if (c.selectedPresetSize == kCustomPreset) ...[
          const Text(
            'Custom Preset Size (Millimeters)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _field(
                controller: _mmWidthCtrl,
                label: 'Width (mm)',
                colors: colors,
                testKey: 'custom_mm_width_field',
                allowDecimal: true,
                onChanged: c.updateCustomMmWidth,
              ),
              const SizedBox(width: 16),
              _field(
                controller: _mmHeightCtrl,
                label: 'Height (mm)',
                colors: colors,
                testKey: 'custom_mm_height_field',
                allowDecimal: true,
                onChanged: c.updateCustomMmHeight,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _aspectRatio(PhotoController c, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aspect Ratio',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _chipWrap(
          [
            'Original',
            'Freeform',
            '1:1',
            '4:3',
            '16:9',
            '9:16',
            '2:3',
            '3:2',
            '21:9',
            kCustomRatio,
          ],
          c.selectedPresetRatio,
          colors,
          (preset) => c.selectPreset(preset),
        ),
        if (c.selectedPresetRatio == kCustomRatio) ...[
          const Text(
            'Custom Aspect Ratio (Width : Height)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _field(
                controller: _ratioWidthCtrl,
                label: 'Width Ratio',
                colors: colors,
                testKey: 'custom_ratio_width_field',
                allowDecimal: true,
                onChanged: c.updateCustomRatioWidth,
              ),
              const SizedBox(width: 16),
              _field(
                controller: _ratioHeightCtrl,
                label: 'Height Ratio',
                colors: colors,
                testKey: 'custom_ratio_height_field',
                allowDecimal: true,
                onChanged: c.updateCustomRatioHeight,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chipWrap(
    List<String> options,
    String selected,
    ColorScheme colors,
    ValueChanged<String> onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final option in options)
            _tapBox(
              height: 38,
              selected: selected == option,
              colors: colors,
              onTap: () => onTap(option),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected == option
                      ? colors.onPrimary
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String text, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compressionCard(PhotoController c, ColorScheme colors) {
    return Card(
      color: colors.primaryContainer.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _segmentPanel(
              colors: colors,
              bottomMargin: 0,
              radius: 12,
              backgroundOpacity: 0.5,
              children: [
                Expanded(
                  child: _tapBox(
                    height: 38,
                    selected: c.isAutoCompress,
                    colors: colors,
                    onTap: () => c.setAutoCompress(true),
                    child: Text(
                      'Auto (High Quality)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: c.isAutoCompress
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _tapBox(
                    height: 38,
                    selected: !c.isAutoCompress,
                    colors: colors,
                    onTap: () => c.setAutoCompress(false),
                    child: Text(
                      'Custom Target Limit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !c.isAutoCompress
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (c.isAutoCompress)
              _infoRow(
                'Preserve maximum fidelity and clarity using standard default JPEG optimization without forced downscaling.',
                colors,
              )
            else ...[
              Text(
                'Configure maximum forced target image size limit below:',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 13,
                    child: TextField(
                      key: const Key('size_limit_field'),
                      controller: _limitCtrl,
                      onChanged: c.setSizeLimit,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Limit amount',
                        hintText: 'e.g. 500',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: colors.primary),
                        ),
                        fillColor: colors.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 10,
                    child: SizedBox(
                      height: 56,
                      child: _segmentPanel(
                        colors: colors,
                        bottomMargin: 0,
                        radius: 24,
                        backgroundOpacity: 0.5,
                        children: [
                          for (final unit in ['KB', 'MB'])
                            Expanded(
                              child: _tapBox(
                                height: 48,
                                selected: c.sizeLimitUnit == unit,
                                colors: colors,
                                onTap: () => c.setSizeUnit(unit),
                                child: Text(
                                  unit,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: c.sizeLimitUnit == unit
                                        ? colors.onPrimaryContainer
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                key: const Key('crop_save_button'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final w = int.tryParse(c.targetWidthInput);
                  final h = int.tryParse(c.targetHeightInput);
                  if (w == null || w <= 0 || h == null || h <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please configure valid non-zero target pixels'),
                      ),
                    );
                  } else {
                    c.openCropping();
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.crop),
                    SizedBox(width: 12),
                    Text(
                      'Crop and Save Selection',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Allows only digits and a single decimal point (mirrors the Kotlin
/// `filter { it.isDigit() || it == '.' }`).
class _DecimalTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    return newValue.copyWith(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}
