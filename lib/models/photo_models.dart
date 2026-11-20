/// Data models for the Photo Resizer port (from the Android `ImageMetadata.kt`
/// and `ViewModel.kt` state definitions).

/// Screen states used by the root navigation controller.
enum ScreenState { welcome, configure, cropping, preview }

/// Output file formats supported by the exporter.
enum ExportFormat { jpg, png, webp }

extension ExportFormatX on ExportFormat {
  String get label => switch (this) {
        ExportFormat.jpg => 'JPG',
        ExportFormat.png => 'PNG',
        ExportFormat.webp => 'WEBP',
      };

  String get extension => label.toLowerCase() == 'jpeg' ? 'jpg' : label.toLowerCase();

  String get mimeType => switch (this) {
        ExportFormat.jpg => 'image/jpeg',
        ExportFormat.png => 'image/png',
        ExportFormat.webp => 'image/webp',
      };

  static ExportFormat fromLabel(String label) => switch (label.toUpperCase()) {
        'PNG' => ExportFormat.png,
        'WEBP' => ExportFormat.webp,
        _ => ExportFormat.jpg,
      };
}

/// Geometric cut shapes applied to the processed image.
enum CutShape { square, circle, triangle }

extension CutShapeX on CutShape {
  String get label => switch (this) {
        CutShape.square => 'Square',
        CutShape.circle => 'Circle',
        CutShape.triangle => 'Triangle',
      };

  static CutShape fromLabel(String label) => switch (label.toLowerCase()) {
        'circle' => CutShape.circle,
        'triangle' => CutShape.triangle,
        _ => CutShape.square,
      };
}

/// Comparison layouts offered on the preview screen.
enum ComparisonMode { splitSlider, sideBySide, quickToggle }

/// Guide overlays offered in the crop editor.
enum GridOption { none, ruleOfThirds, goldenRatio, fourByFour }

extension GridOptionX on GridOption {
  String get label => switch (this) {
        GridOption.none => 'None',
        GridOption.ruleOfThirds => '3x3',
        GridOption.goldenRatio => 'Golden',
        GridOption.fourByFour => '4x4',
      };
}

/// Tool modes in the crop editor bottom bar.
enum CropToolMode { rotation, zoom, perspective4d, grid }

/// Resolution mode for standard document preset sizes.
enum PresetResolutionMode { maximum, original }

extension PresetResolutionModeX on PresetResolutionMode {
  String get label => switch (this) {
        PresetResolutionMode.maximum => 'Maximum',
        PresetResolutionMode.original => 'Original',
      };
}

/// Metadata describing a loaded source image. Mirrors `ImageMetadata.kt`.
class ImageMetadata {
  final int width;
  final int height;
  final int sizeBytes;
  final String? sourcePath;
  final String? originalName;
  final ExportFormat format;

  const ImageMetadata({
    required this.width,
    required this.height,
    required this.sizeBytes,
    this.sourcePath,
    this.originalName,
    this.format = ExportFormat.jpg,
  });

  ImageMetadata copyWith({
    int? width,
    int? height,
    int? sizeBytes,
    String? sourcePath,
    String? originalName,
    ExportFormat? format,
  }) {
    return ImageMetadata(
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sourcePath: sourcePath ?? this.sourcePath,
      originalName: originalName ?? this.originalName,
      format: format ?? this.format,
    );
  }
}

/// Standard document preset sizes and their pixel resolution at 300 DPI.
const Map<String, List<int>> kSizePresets = {
  '25 × 30 mm': [295, 354],
  '25 × 35 mm': [295, 413],
  '30 × 40 mm': [354, 472],
  '30 × 45 mm': [354, 531],
  '33 × 48 mm': [390, 567],
  '35 × 45 mm': [413, 531],
  '40 × 50 mm': [472, 591],
  '45 × 45 mm': [531, 531],
  '50 × 50 mm': [591, 591],
  '51 × 51 mm': [602, 602],
};

const String kCustomPreset = 'Custom preset';
const String kCustomRatio = 'Custom ratio';
