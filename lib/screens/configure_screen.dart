/// Port of `ConfigureScreen.kt`.
///
/// The layout, colors and font sizes below follow the Compose source directly.
/// All colors come from the app's Material 3 [ColorScheme] (set up in main.dart).
import 'package:material_ui/material_ui.dart';
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
  /// Mirrors `rememberSaveable { mutableStateOf("Custom Size") }`.
  String _activeSegment = 'Custom Size';

  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _mmWidthCtrl = TextEditingController();
  final _mmHeightCtrl = TextEditingController();
  final _ratioWidthCtrl = TextEditingController();
  final _ratioHeightCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();

  static const List<String> _segments = ['Custom Size', 'Preset Size', 'Aspect Ratio'];
  static const List<String> _shapes = ['Square', 'Circle', 'Triangle'];
  static final List<String> _sizePresets = [
    ...kSizePresets.keys,
    kCustomPreset,
  ];
  static const List<String> _aspectPresets = [
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
  ];

  @override
  void dispose() {
    for (final controller in [
      _widthCtrl,
      _heightCtrl,
      _mmWidthCtrl,
      _mmHeightCtrl,
      _ratioWidthCtrl,
      _ratioHeightCtrl,
      _limitCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Keeps a text field in sync with controller state without moving the caret.
  void _sync(TextEditingController field, String value) {
    if (field.text == value) return;
    final selection = field.selection;
    field.text = value;
    field.selection = selection;
  }

  @override
  Widget build(BuildContext context) {
    // Read the M3 scheme from the app theme on every build.
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
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
                      _previewCard(meta, colors),
                      _title('Resolution Mode'),
                      _segmentRow(
                        labels: _segments,
                        selected: _activeSegment,
                        colors: colors,
                        onTap: _onSegmentTap,
                      ),
                      const SizedBox(height: 4),
                      switch (_activeSegment) {
                        'Custom Size' => _customSizeSection(colors),
                        'Preset Size' => _presetSizeSection(colors),
                        'Aspect Ratio' => _aspectRatioSection(colors),
                        _ => const SizedBox.shrink(),
                      },
                      _title('Image Cut Shape'),
                      _segmentRow(
                        labels: _shapes,
                        selected: widget.controller.selectedCutShape.label,
                        colors: colors,
                        fontSize: 12,
                        testKeyPrefix: 'shape_segment',
                        onTap: (shape) => c.setCutShape(CutShapeX.fromLabel(shape)),
                      ),
                      _title('File Size Optimization'),
                      _compressionCard(colors),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _onSegmentTap(String segment) {
    setState(() => _activeSegment = segment);
    final c = widget.controller;
    if (segment == 'Aspect Ratio') {
      c.selectPreset(c.selectedPresetRatio);
    } else if (segment == 'Preset Size' && c.selectedPresetSize != 'None') {
      c.selectPresetSize(c.selectedPresetSize);
    } else if (segment == 'Custom Size') {
      // Show the loaded image's own resolution in the target fields, like the
      // Compose screen does when the section is opened.
      c.restoreOriginalResolution();
    }
  }

  // ---------------------------------------------------------------------------
  // Shared building blocks (one-to-one with the Compose modifiers)
  // ---------------------------------------------------------------------------

  /// `Text(... fontSize = 14.sp, fontWeight = Bold, padding(top=8, bottom=8))`.
  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Compose segmented control:
  /// `Row(fillMaxWidth, background(surfaceVariant 0.4, radius 14), padding 4,
  /// spacedBy 4) { Box(weight 1, height 40, clip 10,
  /// background(selected ? primary : Transparent)) { Text(...) } }`
  Widget _segmentRow({
    required List<String> labels,
    required String selected,
    required ColorScheme colors,
    required ValueChanged<String> onTap,
    double fontSize = 11,
    String? testKeyPrefix,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: _segmentButton(
                label: label,
                selected: selected == label,
                colors: colors,
                fontSize: fontSize,
                height: 40,
                radius: 10,
                testKey: testKeyPrefix == null
                    ? null
                    : '${testKeyPrefix}_${label.toLowerCase()}',
                onTap: () => onTap(label),
              ),
            ),
        ],
      ),
    );
  }

  /// The filled "pill" used by every segmented control and chip on this screen.
  Widget _segmentButton({
    required String label,
    required bool selected,
    required ColorScheme colors,
    required double fontSize,
    required double height,
    required double radius,
    required VoidCallback onTap,
    String? testKey,
    bool fillWidth = true,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 4),
  }) {
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: testKey == null ? null : Key(testKey),
          onTap: onTap,
          child: Container(
            width: fillWidth ? double.infinity : null,
            height: height,
            padding: padding,
            // With bounded Wrap constraints, a non-null alignment makes the
            // Container fill the whole row. Chips must stay content-sized so
            // they flow horizontally like Compose's FlowRow.
            alignment: fillWidth ? Alignment.center : null,
            decoration: BoxDecoration(
              color: selected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compose `FlowRow` of chips used for presets.
  Widget _chipRow({
    required List<String> labels,
    required String selected,
    required ColorScheme colors,
    required ValueChanged<String> onTap,
    double fontSize = 11,
  }) {
    return Container(
      width: double.infinity,
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
          for (final label in labels)
            _segmentButton(
              label: label,
              selected: selected == label,
              colors: colors,
              fontSize: fontSize,
              height: 38,
              radius: 10,
              fillWidth: false,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: () => onTap(label),
            ),
        ],
      ),
    );
  }

  /// Compose `OutlinedTextField(shape = RoundedCornerShape(24))`.
  Widget _field({
    required TextEditingController controller,
    required String label,
    required ColorScheme colors,
    required ValueChanged<String> onChanged,
    String? testKey,
    String? hint,
    bool allowDecimal = false,
  }) {
    return Expanded(
      child: TextField(
        key: testKey == null ? null : Key(testKey),
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        inputFormatters: [
          allowDecimal
              ? _DigitsAndDotFormatter()
              : FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: colors.surface,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: colors.primary),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  /// Compose info row: 20 dp info icon + 11/12 sp supporting text.
  Widget _infoRow(String text, ColorScheme colors, {double fontSize = 11}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outlined, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: fontSize, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections (same order as ConfigureScreen.kt)
  // ---------------------------------------------------------------------------

  Widget _previewCard(ImageMetadata meta, ColorScheme colors) {
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
                child: widget.controller.originalDisplayBytes == null
                    ? const SizedBox.shrink()
                    : Image.memory(
                        widget.controller.originalDisplayBytes!,
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
                _metaColumn('Original Format', 'JPEG File', colors),
                _metaColumn(
                  'Resolution',
                  '${meta.width} × ${meta.height} px',
                  colors,
                ),
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
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _customSizeSection(ColorScheme colors) {
    final c = widget.controller;
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
              testKey: 'target_width_field',
              colors: colors,
              onChanged: c.setTargetWidth,
            ),
            const SizedBox(width: 16),
            _field(
              controller: _heightCtrl,
              label: 'Height (px)',
              testKey: 'target_height_field',
              colors: colors,
              onChanged: c.setTargetHeight,
            ),
          ],
        ),
      ],
    );
  }

  Widget _presetSizeSection(ColorScheme colors) {
    final c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Standard Document Preset Sizes',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _chipRow(
          labels: _sizePresets,
          selected: c.selectedPresetSize,
          colors: colors,
          onTap: c.selectPresetSize,
        ),
        if (c.selectedPresetSize != 'None') ...[
          const Text(
            'Preset Resolution Mode',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _segmentRow(
            labels: ['Maximum Resolution', 'Original Preset Size'],
            selected: c.presetResolutionMode.label == 'Maximum'
                ? 'Maximum Resolution'
                : 'Original Preset Size',
            colors: colors,
            onTap: (value) => c.changePresetResolutionMode(
              value == 'Maximum Resolution'
                  ? PresetResolutionMode.maximum
                  : PresetResolutionMode.original,
            ),
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
                testKey: 'custom_mm_width_field',
                colors: colors,
                allowDecimal: true,
                onChanged: c.updateCustomMmWidth,
              ),
              const SizedBox(width: 16),
              _field(
                controller: _mmHeightCtrl,
                label: 'Height (mm)',
                testKey: 'custom_mm_height_field',
                colors: colors,
                allowDecimal: true,
                onChanged: c.updateCustomMmHeight,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _aspectRatioSection(ColorScheme colors) {
    final c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aspect Ratio',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _chipRow(
          labels: _aspectPresets,
          selected: c.selectedPresetRatio,
          colors: colors,
          fontSize: 12,
          onTap: c.selectPreset,
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
                testKey: 'custom_ratio_width_field',
                colors: colors,
                allowDecimal: true,
                onChanged: c.updateCustomRatioWidth,
              ),
              const SizedBox(width: 16),
              _field(
                controller: _ratioHeightCtrl,
                label: 'Height Ratio',
                testKey: 'custom_ratio_height_field',
                colors: colors,
                allowDecimal: true,
                onChanged: c.updateCustomRatioHeight,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _compressionCard(ColorScheme colors) {
    final c = widget.controller;
    return Card(
      color: colors.primaryContainer.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _segmentButton(
                      label: 'Auto (High Quality)',
                      selected: c.isAutoCompress,
                      colors: colors,
                      fontSize: 12,
                      height: 38,
                      radius: 8,
                      onTap: () => c.setAutoCompress(true),
                    ),
                  ),
                  Expanded(
                    child: _segmentButton(
                      label: 'Custom Target Limit',
                      selected: !c.isAutoCompress,
                      colors: colors,
                      fontSize: 12,
                      height: 38,
                      radius: 8,
                      onTap: () => c.setAutoCompress(false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (c.isAutoCompress)
              _infoRow(
                'Preserve maximum fidelity and clarity using standard default JPEG optimization without forced downscaling.',
                colors,
                fontSize: 12,
              )
            else ...[
              Text(
                'Configure maximum forced target image size limit below:',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _field(
                    controller: _limitCtrl,
                    label: 'Limit amount',
                    hint: 'e.g. 500',
                    testKey: 'size_limit_field',
                    colors: colors,
                    onChanged: c.setSizeLimit,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          for (final unit in ['KB', 'MB'])
                            Expanded(
                              child: _unitButton(unit, colors),
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
                  final width = int.tryParse(c.targetWidthInput);
                  final height = int.tryParse(c.targetHeightInput);
                  if (width == null || width <= 0 || height == null || height <= 0) {
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

  /// Compose KB/MB box: `weight 1, fillMaxHeight, clip 20,
  /// background(selected ? primaryContainer : Transparent)`.
  Widget _unitButton(String unit, ColorScheme colors) {
    final selected = widget.controller.sizeLimitUnit == unit;
    return SizedBox(
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.controller.setSizeUnit(unit),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              unit,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Allows digits and a single decimal point, like the Kotlin filter.
class _DigitsAndDotFormatter extends TextInputFormatter {
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
