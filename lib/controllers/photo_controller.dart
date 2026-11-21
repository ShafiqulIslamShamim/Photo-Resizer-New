/// Port of the Android `ViewModel.kt`. Holds all photo-resizer state and the
/// processing pipeline.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

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

  Uint8List? _originalDisplayBytes;
  Uint8List? get originalDisplayBytes => _originalDisplayBytes;

  /// Original file bytes and 90° rotations.
  Uint8List? _sourceBytes;
  int _rotationTurns = 0;
  int get rotationTurns => _rotationTurns;

  int _processedWidth = 0;
  int get processedWidth => _processedWidth;
  int _processedHeight = 0;
  int get processedHeight => _processedHeight;

  Uint8List? _processedDisplayBytes;
  Uint8List? get processedDisplayBytes => _processedDisplayBytes;

  int _processedSizeBytes = 0;
  int get processedSizeBytes => _processedSizeBytes;

  /// Encoded bytes of the processed image.
  Uint8List? _processedEncodedBytes;

  /// Raw RGBA pixels of the processed image for instant format recompression.
  Uint8List? _processedRawRgbaBytes;
  ExportFormat? _lastProcessedFormat;

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
    _originalDisplayBytes = null;
    _sourceBytes = null;
    _rotationTurns = 0;
    _processedWidth = 0;
    _processedHeight = 0;
    _processedDisplayBytes = null;
    _processedEncodedBytes = null;
    _processedRawRgbaBytes = null;
    _lastProcessedFormat = null;
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
    await WidgetsBinding.instance.endOfFrame;
    try {
      // 1. Fast sub-millisecond header parser (mirrors BitmapFactory.Options.inJustDecodeBounds = true)
      final headerInfo = ImageUtils.parseDimensionsAndFormat(
        bytes,
        name: name,
        mimeType: mimeType,
      );

      late final int width;
      late final int height;
      late final ExportFormat format;

      if (headerInfo != null) {
        width = headerInfo.width;
        height = headerInfo.height;
        format = headerInfo.format;
      } else {
        final fallback = await ImageUtils.getImageDimensionsNative(bytes);
        width = fallback.width;
        height = fallback.height;
        format = ImageUtils.detectFormat(bytes, name: name, mimeType: mimeType);
      }

      _originalMetadata = ImageMetadata(
        width: width,
        height: height,
        sizeBytes: bytes.length,
        sourcePath: path,
        originalName: name,
        format: format,
      );
      _sourceBytes = bytes;
      _rotationTurns = 0;
      targetWidthInput = width.toString();
      targetHeightInput = height.toString();

      // 2. Fast native C++ display preview generation (~30ms)
      _originalDisplayBytes = await ImageUtils.createDisplayPreview(
        bytes,
        maxSize: 1400,
        rotationTurns: 0,
      );

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
        targetHeightInput = origH.toString();
        targetWidthInput = (origH * presetRatio).round().toString();
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
    final oldMeta = _originalMetadata;
    final source = _sourceBytes;
    if (oldMeta == null || source == null) return;
    _loading = true;
    notifyListeners();
    await WidgetsBinding.instance.endOfFrame;
    try {
      final nextTurns = (_rotationTurns + 1) % 4;
      _rotationTurns = nextTurns;
      _originalMetadata = oldMeta.copyWith(
        width: oldMeta.height,
        height: oldMeta.width,
      );
      // Fast regeneration of rotated display preview directly from source
      _originalDisplayBytes = await ImageUtils.createDisplayPreview(
        source,
        maxSize: 1400,
        rotationTurns: nextTurns,
      );

      if (selectedPresetRatio == 'Original') {
        targetWidthInput = _originalMetadata!.width.toString();
        targetHeightInput = _originalMetadata!.height.toString();
      } else {
        selectPreset(selectedPresetRatio);
      }
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
    final meta = _originalMetadata;
    if (source == null || meta == null) return;
    _loading = true;
    notifyListeners();
    await WidgetsBinding.instance.endOfFrame;
    try {
      final targetW = int.tryParse(targetWidthInput) ?? meta.width;
      final targetH = int.tryParse(targetHeightInput) ?? meta.height;
      final exportFmt = _originalMetadata?.format ?? ExportFormat.jpg;
      final sizeLimit = _currentSizeLimitKb();

      // Native C++ decode + crop + transform + scale + mask (~50-100ms)
      final result = await ImageUtils.cropAndTransform(
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
        targetWidth: targetW,
        targetHeight: targetH,
        cutShape: selectedCutShape,
        exportFormat: exportFmt,
        sizeLimitKb: sizeLimit,
      );

      _processedWidth = result.width;
      _processedHeight = result.height;
      _processedRawRgbaBytes = result.rawRgbaBytes;
      _processedEncodedBytes = result.bytes;
      _processedDisplayBytes = result.displayBytes;
      _processedSizeBytes = result.bytes.length;
      _lastProcessedFormat = exportFmt;
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

  /// Recomputes the expected export size for a chosen output format.
  /// Fast background encode from cached uncompressed RGBA bytes (< 50ms).
  Future<int> computeSavedBytesAsync(ExportFormat format) async {
    if (format == _lastProcessedFormat && _processedEncodedBytes != null) {
      return _processedEncodedBytes!.length;
    }
    final rawRgba = _processedRawRgbaBytes;
    if (rawRgba == null) {
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
    try {
      final bytes = await compute(
        compressRawInBackground,
        CompressRawRequest(
          rawRgbaBytes: rawRgba,
          width: _processedWidth,
          height: _processedHeight,
          exportFormat: format.label,
          sizeLimitKb: _currentSizeLimitKb(),
        ),
      );
      return bytes.length;
    } catch (_) {
      return _processedSizeBytes;
    }
  }

  /// Encodes the processed image for export in the chosen format.
  Future<Uint8List> encodeForExport(ExportFormat format) async {
    if (format == _lastProcessedFormat && _processedEncodedBytes != null) {
      return _processedEncodedBytes!;
    }
    final rawRgba = _processedRawRgbaBytes;
    if (rawRgba != null) {
      return compute(
        compressRawInBackground,
        CompressRawRequest(
          rawRgbaBytes: rawRgba,
          width: _processedWidth,
          height: _processedHeight,
          exportFormat: format.label,
          sizeLimitKb: _currentSizeLimitKb(),
        ),
      );
    }
    final encoded = _processedEncodedBytes;
    if (encoded == null) return Uint8List(0);
    return compute(
      encodeForExportInBackground,
      RecompressRequest(
        processedBytes: encoded,
        exportFormat: format.label,
        sizeLimitKb: _currentSizeLimitKb(),
      ),
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
