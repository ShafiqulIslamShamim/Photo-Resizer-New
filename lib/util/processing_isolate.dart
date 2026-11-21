/// Background isolate tasks for photo operations.
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/photo_models.dart';
import 'image_utils.dart';

/// Sendable request passed to the background isolate.
class ProcessRequest {
  final Uint8List sourceBytes;
  final int rotationTurns;
  final int left;
  final int top;
  final int width;
  final int height;
  final double fineRotation;
  final double perspectiveX;
  final double perspectiveY;
  final List<double>? perspectivePoints;
  final int targetWidth;
  final int targetHeight;
  final String cutShape;
  final String exportFormat;
  final int? sizeLimitKb;

  const ProcessRequest({
    required this.sourceBytes,
    required this.rotationTurns,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.fineRotation,
    required this.perspectiveX,
    required this.perspectiveY,
    this.perspectivePoints,
    required this.targetWidth,
    required this.targetHeight,
    required this.cutShape,
    required this.exportFormat,
    required this.sizeLimitKb,
  });
}

/// Sendable result returned by the background isolate.
class ProcessResult {
  final Uint8List bytes;
  final Uint8List displayBytes;
  final Uint8List? rawRgbaBytes;
  final int width;
  final int height;

  const ProcessResult({
    required this.bytes,
    required this.displayBytes,
    this.rawRgbaBytes,
    required this.width,
    required this.height,
  });
}

/// Request for decoding a freshly picked image in the background.
class LoadRequest {
  final Uint8List bytes;
  final String? name;
  final String? path;
  final String? mimeType;
  final int rotationTurns;

  const LoadRequest({
    required this.bytes,
    this.name,
    this.path,
    this.mimeType,
    this.rotationTurns = 0,
  });
}

/// Sendable result of the background image load.
class LoadResult {
  final int width;
  final int height;
  final int sizeBytes;
  final String formatLabel;
  final String? originalName;
  final String? sourcePath;
  final Uint8List displayBytes;

  const LoadResult({
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.formatLabel,
    required this.originalName,
    required this.sourcePath,
    required this.displayBytes,
  });
}

/// Decodes an image and produces a display preview.
LoadResult loadImageInBackground(LoadRequest request) {
  var image = ImageUtils.decodeCorrected(request.bytes);
  if (image == null) {
    throw StateError('Unable to decode image');
  }
  if (request.rotationTurns % 4 != 0) {
    image = img.copyRotate(
      image,
      angle: 90.0 * (request.rotationTurns % 4),
      interpolation: img.Interpolation.nearest,
    );
  }
  final display = ImageUtils.createDisplayCopy(image);
  return LoadResult(
    width: image.width,
    height: image.height,
    sizeBytes: request.bytes.length,
    formatLabel: ImageUtils.detectFormat(
      request.bytes,
      name: request.name,
      mimeType: request.mimeType,
    ).label,
    originalName: request.name,
    sourcePath: request.path,
    displayBytes: ImageUtils.toJpegBytes(display),
  );
}

/// Request used to recompute the export size for a different format.
class RecompressRequest {
  final Uint8List processedBytes;
  final String exportFormat;
  final int? sizeLimitKb;

  const RecompressRequest({
    required this.processedBytes,
    required this.exportFormat,
    required this.sizeLimitKb,
  });
}

/// Request used to encode an uncompressed raw RGBA buffer to a target format.
class CompressRawRequest {
  final Uint8List rawRgbaBytes;
  final int width;
  final int height;
  final String exportFormat;
  final int? sizeLimitKb;

  const CompressRawRequest({
    required this.rawRgbaBytes,
    required this.width,
    required this.height,
    required this.exportFormat,
    required this.sizeLimitKb,
  });
}

/// Encodes raw RGBA bytes to target format with optional size limit in background.
Uint8List compressRawInBackground(CompressRawRequest request) {
  return ImageUtils.compressRawRgbaBytes(
    rawRgbaBytes: request.rawRgbaBytes,
    width: request.width,
    height: request.height,
    format: ExportFormatX.fromLabel(request.exportFormat),
    sizeLimitKb: request.sizeLimitKb,
  );
}

/// Re-encodes the processed image off the UI thread so switching JPG/PNG/WEBP
/// segments never freezes the preview screen.
int recompressInBackground(RecompressRequest request) {
  final image = img.decodeImage(request.processedBytes);
  if (image == null) return 0;
  return ImageUtils.compressBitmapToBytes(
    image,
    quality: 100,
    format: ExportFormatX.fromLabel(request.exportFormat),
    sizeLimitKb: request.sizeLimitKb,
  ).length;
}

/// Encodes the final export bytes off the UI thread.
Uint8List encodeForExportInBackground(RecompressRequest request) {
  final image = img.decodeImage(request.processedBytes);
  if (image == null) return Uint8List(0);
  return ImageUtils.compressBitmapToBytes(
    image,
    quality: 100,
    format: ExportFormatX.fromLabel(request.exportFormat),
    sizeLimitKb: request.sizeLimitKb,
  );
}

/// Pure Dart background isolate fallback for crop/resize/mask/compress.
Future<ProcessResult> processPhotoInBackground(ProcessRequest request) async {
  var source = ImageUtils.decodeCorrected(request.sourceBytes);
  if (source == null) {
    throw StateError('Unable to decode source image');
  }

  if (request.rotationTurns % 4 != 0) {
    source = img.copyRotate(
      source,
      angle: 90.0 * (request.rotationTurns % 4),
      interpolation: img.Interpolation.nearest,
    );
  }

  late final img.Image transformed;
  final points = request.perspectivePoints;
  if (points != null) {
    transformed = ImageUtils.apply4PointPerspectiveWarp(source, points);
  } else {
    final cropped = ImageUtils.cropRect(
      source,
      request.left,
      request.top,
      request.width,
      request.height,
    );
    transformed = ImageUtils.applyFineTransform(
      cropped,
      rotationZ: request.fineRotation,
      rotationX: request.perspectiveX,
      rotationY: request.perspectiveY,
    );
  }

  final scaled = ImageUtils.scaleTo(
    transformed,
    request.targetWidth,
    request.targetHeight,
  );
  final masked = ImageUtils.applyShapeMask(
    scaled,
    CutShapeX.fromLabel(request.cutShape),
  );
  final bytes = ImageUtils.compressBitmapToBytes(
    masked,
    quality: 100,
    format: ExportFormatX.fromLabel(request.exportFormat),
    sizeLimitKb: request.sizeLimitKb,
  );
  final finalBitmap = img.decodeImage(bytes) ?? masked;

  return ProcessResult(
    bytes: bytes,
    displayBytes: ImageUtils.toPngBytes(
      ImageUtils.createDisplayCopy(finalBitmap),
    ),
    rawRgbaBytes: masked.toUint8List(),
    width: finalBitmap.width,
    height: finalBitmap.height,
  );
}
