/// Port of the Android `ViewModel.kt`. Holds all photo-resizer state and the
/// processing pipeline. Pure Dart so it behaves the same on every platform.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:image/image.dart' as img;

import '../models/photo_models.dart';
import '../util/image_utils.dart';
import '../util/processing_isolate.dart';

class PhotoController extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Navigation / progress
  // ---------------------------------------------------------------------------
  ScreenState _screenState = ScreenState.welcome;
  ScreenState get screenState => _screenState;

  bool _loading = false;
  bool get loading => _loading;

  String? _oomDialogMessage;
  String? get oomDialogMessage => _oomDialogMessage;

  /// One-off message shown by the root widget in a SnackBar (Android Toast port).
  String? _transientMessage;
  String? get transientMessage => _transientMessage;

  void clearTransientMessage() {
    _transientMessage = null;
  }

  void dismissOomDialog() {
    _oomDialogMessage = null;
    notifyListeners();
  }

  /// Mirrors the ViewModel.kt catches: OutOfMemoryError shows the memory dialog,
  /// every other Throwable becomes a one-off Toast (or is ignored for rotation).
  bool _isOutOfMemory(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('out of memory') ||
        message.contains('oom') ||
        message.contains('allocation failed') ||
        message.contains('could not allocate');
  }

  String _errorMessage(Object error) {
    final text = error.toString().trim();
    final colon = text.indexOf(':');
    return colon >= 0 ? text.substring(colon + 1).trim() : text;
  }

  void _reportFailure(
    Object error, {
    required String oomMessage,
    String? toastPrefix,
  }) {
    if (_isOutOfMemory(error)) {
      _oomDialogMessage = oomMessage;
    } else if (toastPrefix != null) {
      _transientMessage = toastPrefix + _errorMessage(error);
    }
  }

  // ---------------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------------
  ImageMetadata? _originalMetadata;
  ImageMetadata? get originalMetadata => _originalMetadata;

  img.Image? _originalImage;
  img.Image? get originalImage => _originalImage;

  Uint8List? _originalDisplayBytes;
  Uint8List? get originalDisplayBytes => _originalDisplayBytes;

  /// Original file bytes and 90° rotations, used by the background isolate so
  /// the crop pipeline never runs on the UI thread.
  Uint8List? _sourceBytes;
  int _rotationTurns = 0;

  img.Image? _processedImage;
  img.Image? get processedImage => _processedImage;

  Uint8List? _processedDisplayBytes;
  Uint8List? get processedDisplayBytes => _processedDisplayBytes;

  int _processedSizeBytes = 0;
  int get processedSizeBytes => _processedSizeBytes;

  /// Encoded bytes of the processed image, used to recompute export size for
  /// other formats without blocking the UI.
  Uint8List? _processedEncodedBytes;

  // ---------------------------------------------------------------------------
  // Configuration inputs
  // ---------------------------------------------------------------------------
  String targetWidthInput = '';
  String targetHeightInput = '';

  bool isAutoCompress = true;
  String sizeLimitInput = '';
  String sizeLimitUnit = 'KB';

  String selectedPresetRatio = 'Original';
  String selectedPresetSize = 'None';
  CutShape selectedCutShape = CutShape.square;

  String customMmWidth = '';
  String customMmHeight = '';
  String customRatioWidth = '';
  String customRatioHeight = '';

  PresetResolutionMode presetResolutionMode = PresetResolutionMode.original;

  // ---------------------------------------------------------------------------
  // State transitions
  // ---------------------------------------------------------------------------
  void reset() {
    _originalMetadata = null;
    _originalImage = null;
    _originalDisplayBytes = null;
    _sourceBytes = null;
    _rotationTurns = 0;
    _processedImage = null;
    _processedDisplayBytes = null;
    _processedEncodedBytes = null;
    _processedSizeBytes = 0;
    _oomDialogMessage = null;
    targetWidthInput = '';
    targetHeightInput = '';
    isAutoCompress = true;
    sizeLimitInput = '';
    sizeLimitUnit = 'KB';
    selectedPresetRatio = 'Original';
    selectedPresetSize = 'None';
    selectedCutShape = CutShape.square;
    presetResolutionMode = PresetResolutionMode.original;
    customMmWidth = '';
    customMmHeight = '';
    customRatioWidth = '';
    customRatioHeight = '';
    _screenState = ScreenState.welcome;
    notifyListeners();
  }

  /// Restores the loaded image's own resolution into the target fields.
  /// Used when the user switches back to the "Custom Size" section.
  void restoreOriginalResolution() {
    final meta = _originalMetadata;
    if (meta == null) return;
    targetWidthInput = meta.width.toString();
    targetHeightInput = meta.height.toString();
    selectedPresetRatio = 'Original';
    selectedPresetSize = 'None';
    notifyListeners();
  }

  void backToConfigure() {
    _screenState = ScreenState.configure;
    notifyListeners();
  }

  /// Keeps controller state in sync when the user navigates with the device
  /// back button (route pops) instead of one of the screen callbacks.
  /// Deliberately silent: the navigator already reflects the new route.
  void syncScreenState(ScreenState state) {
    if (_screenState == state) return;
    _screenState = state;
  }

  void openCropping() {
    if (originalMetadata == null) return;
    _screenState = ScreenState.cropping;
    notifyListeners();
  }

  void cancelCropping() {
    _screenState = ScreenState.configure;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Loading an image
  // ---------------------------------------------------------------------------
  Future<void> setImage({
    required Uint8List bytes,
    String? name,
    String? path,
    String? mimeType,
  }) async {
    _loading = true;
    notifyListeners();
    // Wait until the loading overlay has actually been painted. A zero-delay
    // future can resume before the next frame, so fast decodes would finish
    // before the spinner ever became visible.
    await WidgetsBinding.instance.endOfFrame;
    try {
      // Decode once and reuse the result for both metadata and display pixels.
      final decoded = ImageUtils.decodeCorrected(bytes);
      if (decoded == null) {
        _transientMessage = 'Failed to inspect image details';
        return;
      }
      final metadata = ImageUtils.buildMetadata(
        bytes,
        name: name,
        path: path,
        mimeType: mimeType,
        decodedImage: decoded,
      );
      if (metadata == null) {
        _transientMessage = 'Failed to inspect image details';
        return;
      }

      _originalMetadata = metadata;
      _originalImage = decoded;
      _sourceBytes = bytes;
      _rotationTurns = 0;
      final display = ImageUtils.createDisplayCopy(decoded);
      _originalDisplayBytes = ImageUtils.toPngBytes(display);
      targetWidthInput = metadata.width.toString();
      targetHeightInput = metadata.height.toString();
      _screenState = ScreenState.configure;
    } catch (e) {
      _reportFailure(
        e,
        oomMessage:
            'Your device memory is not capable of loading an image at this high resolution. Please try selecting a lower resolution photo or decrease the image resolution.',
        toastPrefix: 'Failed to load image: ',
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Presets
  // ---------------------------------------------------------------------------
  void selectPreset(String ratioName) {
    selectedPresetRatio = ratioName;
    selectedPresetSize = 'None';
    final meta = _originalMetadata;
    if (meta == null) {
      notifyListeners();
      return;
    }
    final currentW = meta.width;
    final currentH = meta.height;
    switch (ratioName) {
      case 'Original':
      case 'Freeform':
        targetWidthInput = currentW.toString();
        targetHeightInput = currentH.toString();
        break;
      case '1:1':
        final size = math.min(currentW, currentH);
        targetWidthInput = size.toString();
        targetHeightInput = size.toString();
        break;
      case '4:3':
        targetWidthInput = currentW.toString();
        targetHeightInput = ((currentW * 3) ~/ 4).toString();
        break;
      case '16:9':
        targetWidthInput = currentW.toString();
        targetHeightInput = ((currentW * 9) ~/ 16).toString();
        break;
      case '9:16':
        targetWidthInput = currentW.toString();
        targetHeightInput = ((currentW * 16) ~/ 9).toString();
        break;
      case '2:3':
        targetWidthInput = currentW.toString();
        targetHeightInput = ((currentW * 3) ~/ 2).toString();
        break;
      case '3:2':
        targetWidthInput = currentW.toString();
        targetHeightInput = ((currentW * 2) ~/ 3).toString();
        break;
      case '21:9':
        targetWidthInput = currentW.toString();
        targetHeightInput = ((currentW * 9) ~/ 21).toString();
        break;
      case kCustomRatio:
        _recalculateCustomRatio();
        break;
    }
    notifyListeners();
  }

  void selectPresetSize(String presetName) {
    selectedPresetSize = presetName;
    selectedPresetRatio = 'Custom';
    if (presetName != 'None') updatePresetSizeResolution();
    notifyListeners();
  }

  void changePresetResolutionMode(PresetResolutionMode mode) {
    presetResolutionMode = mode;
    updatePresetSizeResolution();
    notifyListeners();
  }

  void updateCustomMmWidth(String value) {
    customMmWidth = _digitsAndDot(value);
    updatePresetSizeResolution();
    notifyListeners();
  }

  void updateCustomMmHeight(String value) {
    customMmHeight = _digitsAndDot(value);
    updatePresetSizeResolution();
    notifyListeners();
  }

  void updateCustomRatioWidth(String value) {
    customRatioWidth = _digitsAndDot(value);
    _recalculateCustomRatio();
    notifyListeners();
  }

  void updateCustomRatioHeight(String value) {
    customRatioHeight = _digitsAndDot(value);
    _recalculateCustomRatio();
    notifyListeners();
  }

  void setTargetWidth(String value) {
    targetWidthInput = _digitsOnly(value);
    selectedPresetRatio = 'Custom';
    selectedPresetSize = 'None';
    notifyListeners();
  }

  void setTargetHeight(String value) {
    targetHeightInput = _digitsOnly(value);
    selectedPresetRatio = 'Custom';
    selectedPresetSize = 'None';
    notifyListeners();
  }

  void setSizeLimit(String value) {
    sizeLimitInput = _digitsOnly(value);
    notifyListeners();
  }

  void setSizeUnit(String unit) {
    sizeLimitUnit = unit;
    notifyListeners();
  }

  void setCutShape(CutShape shape) {
    selectedCutShape = shape;
    notifyListeners();
  }

  void setAutoCompress(bool value) {
    isAutoCompress = value;
    notifyListeners();
  }

  static final RegExp _nonDigits = RegExp(r'[^0-9]');
  static final RegExp _nonDigitsOrDot = RegExp(r'[^0-9.]');

  static String _digitsOnly(String s) => s.replaceAll(_nonDigits, '');
  static String _digitsAndDot(String s) => s.replaceAll(_nonDigitsOrDot, '');

  void _recalculateCustomRatio() {
    final rw = double.tryParse(customRatioWidth);
    final rh = double.tryParse(customRatioHeight);
    final meta = _originalMetadata;
    if (meta == null) return;
    if (rw != null && rh != null && rw > 0 && rh > 0) {
      final targetH = (meta.width * rh / rw).round();
      targetWidthInput = meta.width.toString();
      targetHeightInput = targetH.toString();
    } else {
      targetWidthInput = meta.width.toString();
      targetHeightInput = meta.height.toString();
    }
  }

  void updatePresetSizeResolution() {
    final presetName = selectedPresetSize;
    if (presetName == 'None') return;
    final meta = _originalMetadata;
    if (meta == null) return;
    final origW = meta.width;
    final origH = meta.height;

    List<int> resolution;
    if (presetName == kCustomPreset) {
      final mmW = double.tryParse(customMmWidth) ?? 1.0;
      final mmH = double.tryParse(customMmHeight) ?? 1.0;
      resolution = [
        (mmW * 300.0 / 25.4).round(),
        (mmH * 300.0 / 25.4).round(),
      ];
    } else {
      resolution = kSizePresets[presetName] ?? [origW, origH];
    }
    final presetW = resolution[0];
    final presetH = resolution[1];

    if (presetResolutionMode == PresetResolutionMode.maximum) {
      final presetRatio = presetW / presetH;
      final origRatio = origW / origH;
      if (presetRatio > origRatio) {
        targetWidthInput = origW.toString();
        targetHeightInput = (origW / presetRatio).round().toString();
      } else {
        targetWidthInput = (origH * presetRatio).round().toString();
        targetHeightInput = origH.toString();
      }
    } else {
      targetWidthInput = presetW.toString();
      targetHeightInput = presetH.toString();
    }
  }

  // ---------------------------------------------------------------------------
  // Processing
  // ---------------------------------------------------------------------------
  Future<void> rotateOriginal() async {
    final bitmap = _originalImage;
    if (bitmap == null) return;
    _loading = true;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    try {
      final rotated = ImageUtils.rotate90(bitmap);
      _originalImage = rotated;
      _rotationTurns = (_rotationTurns + 1) % 4;
      final oldMeta = _originalMetadata;
      if (oldMeta != null) {
        _originalMetadata = oldMeta.copyWith(
          width: rotated.width,
          height: rotated.height,
        );
        if (selectedPresetRatio == 'Original') {
          targetWidthInput = rotated.width.toString();
          targetHeightInput = rotated.height.toString();
        } else {
          selectPreset(selectedPresetRatio);
        }
      }
      _originalDisplayBytes = ImageUtils.toPngBytes(
        ImageUtils.createDisplayCopy(rotated),
      );
    } catch (e) {
      // Compose silently ignores non-OOM rotation failures.
      _reportFailure(
        e,
        oomMessage:
            'Your device memory is not capable of rotating an image at this resolution. Please try decreasing the resolution first.',
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Crops/resizes/masks/compresses the source and moves to the preview screen.
  Future<void> confirmCropAndProcess({
    required int pixelLeft,
    required int pixelTop,
    required int croppedW,
    required int croppedH,
    double fineRotation = 0,
    double perspectiveX = 0,
    double perspectiveY = 0,
    List<double>? perspectivePoints,
  }) async {
    final source = _sourceBytes;
    final bitmap = _originalImage;
    if (source == null || bitmap == null) return;
    _loading = true;
    notifyListeners();
    // Let the loading overlay paint before the isolate starts.
    await Future<void>.delayed(Duration.zero);
    try {
      final request = ProcessRequest(
        sourceBytes: source,
        rotationTurns: _rotationTurns,
        left: pixelLeft,
        top: pixelTop,
        width: croppedW,
        height: croppedH,
        fineRotation: fineRotation,
        perspectiveX: perspectiveX,
        perspectiveY: perspectiveY,
        perspectivePoints: perspectivePoints,
        targetWidth: int.tryParse(targetWidthInput) ?? bitmap.width,
        targetHeight: int.tryParse(targetHeightInput) ?? bitmap.height,
        cutShape: selectedCutShape.label,
        exportFormat: (_originalMetadata?.format ?? ExportFormat.jpg).label,
        sizeLimitKb: _currentSizeLimitKb(),
      );

      // All heavy pixel work happens on a separate isolate. The UI stays
      // responsive, so Android never shows an ANR / "App isn't responding".
      final result = await compute(processPhotoInBackground, request);

      _processedImage = img.decodeImage(result.bytes);
      _processedEncodedBytes = result.bytes;
      _processedDisplayBytes = result.displayBytes;
      _processedSizeBytes = result.bytes.length;
      _screenState = ScreenState.preview;
    } catch (e) {
      _reportFailure(
        e,
        oomMessage:
            'Your device memory is not capable of processing this image resolution. Please decrease the target resolution or reduce the cropped area.',
        toastPrefix: 'Processing error: ',
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  int? _currentSizeLimitKb() {
    if (isAutoCompress || sizeLimitInput.trim().isEmpty) return null;
    final input = int.tryParse(sizeLimitInput);
    if (input == null || input <= 0) return null;
    return sizeLimitUnit == 'MB' ? input * 1024 : input;
  }

  /// Recomputes the expected export size for a chosen output format on a
  /// background isolate, so switching JPG/PNG/WEBP never freezes the UI.
  Future<int> computeSavedBytesAsync(ExportFormat format) async {
    final encoded = _processedEncodedBytes;
    if (encoded == null) return 0;
    try {
      return await compute(
        recompressInBackground,
        RecompressRequest(
          processedBytes: encoded,
          exportFormat: format.label,
          sizeLimitKb: _currentSizeLimitKb(),
        ),
      );
    } catch (_) {
      return _processedSizeBytes;
    }
  }

  /// Encodes the processed image for export in the chosen format.
  Uint8List encodeForExport(ExportFormat format) {
    return ImageUtils.compressBitmapToBytes(
      _processedImage!,
      quality: 100,
      format: format,
      sizeLimitKb: _currentSizeLimitKb(),
    );
  }

  String suggestedExportName() {
    final original = _originalMetadata?.originalName;
    if (original != null && original.isNotEmpty) {
      final dot = original.lastIndexOf('.');
      if (dot != -1) return original.substring(0, dot);
      return original;
    }
    return 'Photo-Resizer_${DateTime.now().millisecondsSinceEpoch}';
  }
}
