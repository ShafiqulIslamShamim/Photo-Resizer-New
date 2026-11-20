/// Port of `PreviewScreen.kt` — comparison views, output format and export.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../controllers/photo_controller.dart';
import '../models/photo_models.dart';
import '../util/export_service.dart';
import '../util/image_utils.dart';
import '../widgets/app_bar_circle_button.dart';

class PreviewScreen extends StatefulWidget {
  final PhotoController controller;
  final VoidCallback onSettingsClick;

  const PreviewScreen({
    super.key,
    required this.controller,
    required this.onSettingsClick,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  ComparisonMode _compareMode = ComparisonMode.sideBySide;
  bool _showProcessed = true;
  late ExportFormat _format;
  ExportFormat? _cachedFor;
  int _cachedBytes = 0;
  double _sliderFraction = 0.5;

  @override
  void initState() {
    super.initState();
    _format = widget.controller.originalMetadata?.format ?? ExportFormat.jpg;
  }

  void _selectFormat(ExportFormat format) {
    setState(() => _format = format);
  }

  int _savedBytes(PhotoController c) {
    if (_cachedFor != _format) {
      _cachedBytes = c.computeSavedBytes(_format);
      _cachedFor = _format;
    }
    return _cachedBytes;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final meta = c.originalMetadata;
        final processedBytes = c.processedDisplayBytes;
        final saved = _savedBytes(c);
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
              onPressed: c.backToConfigure,
            ),
            title: const Text(
              'Optimization Results',
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
            child: meta == null || processedBytes == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _statsCard(meta, saved, colors),
                      _segmented(colors),
                      _compareCard(c, meta, processedBytes, saved, colors),
                      const SizedBox(height: 4),
                      const Text(
                        'Export File Format',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      _formatPicker(colors),
                      FilledButton(
                        key: const Key('save_to_gallery_button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _export(c),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 12),
                            Text(
                              'Save Image to Pictures',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: c.reset,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh),
                            SizedBox(width: 12),
                            Text('Process Another Photo', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _statsCard(ImageMetadata meta, int saved, ColorScheme colors) {
    final pct = meta.sizeBytes > 0
        ? (((meta.sizeBytes - saved) / meta.sizeBytes) * 100).round().clamp(0, 100)
        : 0;
    return Card(
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$pct% Scaled Down',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compressed ${ImageUtils.formatFileSize(meta.sizeBytes)} to ${ImageUtils.formatFileSize(saved)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'A perfect slim copy optimized for online portals, applications, or social sharing.',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmented(ColorScheme colors) {
    final modes = [
      (ComparisonMode.splitSlider, 'Split View'),
      (ComparisonMode.sideBySide, 'Dual Grid'),
      (ComparisonMode.quickToggle, 'Tab Switch'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final entry in modes)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _compareMode = entry.$1),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _compareMode == entry.$1 ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    entry.$2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _compareMode == entry.$1
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _compareCard(
    PhotoController c,
    ImageMetadata meta,
    Uint8List processed,
    int saved,
    ColorScheme colors,
  ) {
    final original = c.originalDisplayBytes;
    return Card(
      color: colors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            switch (_compareMode) {
              ComparisonMode.splitSlider => _splitCompare(original, processed, colors),
              ComparisonMode.sideBySide => _sideBySide(original, processed, meta, saved, colors),
              ComparisonMode.quickToggle => _quickToggle(original, processed, colors),
            },
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Output Dimensions',
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                    Text(
                      '${c.processedImage?.width ?? 0} × ${c.processedImage?.height ?? 0} px',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'New File Size',
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                    Text(
                      ImageUtils.formatFileSize(saved),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitCompare(Uint8List? original, Uint8List processed, ColorScheme colors) {
    return Column(
      children: [
        Text(
          '◀ Drag handle to compare Original (Left) vs Processed (Right) ▶',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    if (original != null)
                      Positioned.fill(
                        child: Image.memory(original, fit: BoxFit.contain),
                      ),
                    Positioned.fill(
                      child: ClipPath(
                        clipper: _RightFractionClipper(_sliderFraction),
                        child: Image.memory(processed, fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      left: width * _sliderFraction - 1.25,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2.5, color: Colors.white),
                    ),
                    Positioned(
                      left: width * _sliderFraction - 20,
                      top: 110,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (d) {
                          setState(() {
                            _sliderFraction =
                                (_sliderFraction + d.delta.dx / width).clamp(0.001, 0.999);
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Center(
                            child: Icon(Icons.unfold_more, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _sideBySide(
    Uint8List? original,
    Uint8List processed,
    ImageMetadata meta,
    int saved,
    ColorScheme colors,
  ) {
    return SizedBox(
      height: 260,
      child: Row(
        children: [
          Expanded(
            child: _imageFrame(
              original == null ? const SizedBox.shrink() : Image.memory(original, fit: BoxFit.contain),
              'Before (${ImageUtils.formatFileSize(meta.sizeBytes)})',
              Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _imageFrame(
              Image.memory(processed, fit: BoxFit.contain),
              'After (${ImageUtils.formatFileSize(saved)})',
              colors.primary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFrame(Widget child, String label, Color labelColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black.withValues(alpha: 0.05),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: labelColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickToggle(Uint8List? original, Uint8List processed, ColorScheme colors) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: _toggleTab(
                  'Optimized View',
                  _showProcessed,
                  colors,
                  () => setState(() => _showProcessed = true),
                ),
              ),
              Expanded(
                child: _toggleTab(
                  'Original View',
                  !_showProcessed,
                  colors,
                  () => setState(() => _showProcessed = false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _showProcessed
                    ? Image.memory(
                        processed,
                        key: const ValueKey('processed'),
                        fit: BoxFit.contain,
                      )
                    : (original == null
                        ? const SizedBox.shrink()
                        : Image.memory(
                            original,
                            key: const ValueKey('original'),
                            fit: BoxFit.contain,
                          )),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggleTab(
    String label,
    bool active,
    ColorScheme colors,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? colors.onPrimaryContainer : colors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _formatPicker(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final format in ExportFormat.values)
            Expanded(
              child: InkWell(
                key: Key('format_picker_${format.label}'),
                onTap: () => _selectFormat(format),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _format == format ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    format.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _format == format ? colors.onPrimary : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _export(PhotoController c) async {
    try {
      final bytes = c.encodeForExport(_format);
      final name = '${c.suggestedExportName()}.${_format.extension}';
      final ok = await ExportService.saveBytes(bytes, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Saved successfully to Pictures/Photo-Resizer!'
                : 'Failed to export image',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export image')),
      );
    }
  }
}

/// Clips a comparison image to the right-hand [fraction] of its box.
class _RightFractionClipper extends CustomClipper<Rect> {
  final double fraction;

  const _RightFractionClipper(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
        size.width * fraction,
        0,
        size.width * (1 - fraction),
        size.height,
      );

  @override
  bool shouldReclip(covariant _RightFractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}
