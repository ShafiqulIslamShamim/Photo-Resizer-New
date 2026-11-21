/// Runs the expensive crop/resize/mask/compress pipeline on a background
/// isolate so high-resolution photos never block the UI thread (which caused
/// Android's "App isn't responding" dialog).
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
  final int width;
  final int height;

  const ProcessResult({
    required this.bytes,
    required this.displayBytes,
    required this.width,
    required this.height,
  });
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

/// Top-level entry point for `compute()`.
Future<ProcessResult> processPhotoInBackground(ProcessRequest request) async {
  var source = ImageUtils.decodeCorrected(request.sourceBytes);
  if (source == null) {
    throw StateError('Unable to decode source image');
  }

  // Apply the rotations the user performed in the crop editor.
  if (request.rotationTurns != 0) {
    source = img.copyRotate(
      source,
      angle: 90.0 * request.rotationTurns,
      interpolation: img.Interpolation.cubic,
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
    width: finalBitmap.width,
    height: finalBitmap.height,
  );
}
