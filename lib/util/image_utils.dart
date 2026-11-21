/// Pure-Dart port of the Android `Util.kt` image helpers.
///
/// Uses the `image` package so it works identically on Android, iOS and web
/// (no platform channels, no Android `Bitmap`/`Canvas` APIs).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/photo_models.dart';

class ImageUtils {
  /// Formats binary byte sizes to a human-readable string ("1.52 MB" / "450.2 KB").
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    final sizeKb = bytes / 1024.0;
    if (sizeKb >= 1024.0) {
      final rounded = ((sizeKb / 1024.0) * 100).toInt() / 100.0;
      return '$rounded MB';
    }
    final rounded = (sizeKb * 100).toInt() / 100.0;
    return '$rounded KB';
  }

  /// Aspect ratio text such as "16:9", reduced by the greatest common divisor.
  static String getAspectRatioText(int width, int height) {
    if (width <= 0 || height <= 0) return 'N/A';
    final gcd = _gcd(width.abs(), height.abs());
    if (gcd == 0) return 'N/A';
    return '${width ~/ gcd}:${height ~/ gcd}';
  }

  static int _gcd(int a, int b) {
    var n1 = a;
    var n2 = b;
    while (n2 != 0) {
      final r = n1 % n2;
      n1 = n2;
      n2 = r;
    }
    return n1;
  }

  /// Detects the source format from magic bytes, falling back to name/mime type.
  static ExportFormat detectFormat(
    Uint8List bytes, {
    String? name,
    String? mimeType,
  }) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return ExportFormat.png;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return ExportFormat.webp;
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return ExportFormat.jpg;
    }
    final lowerMime = (mimeType ?? '').toLowerCase();
    if (lowerMime.contains('png')) return ExportFormat.png;
    if (lowerMime.contains('webp')) return ExportFormat.webp;
    final lowerName = (name ?? '').toLowerCase();
    if (lowerName.endsWith('.png')) return ExportFormat.png;
    if (lowerName.endsWith('.webp')) return ExportFormat.webp;
    return ExportFormat.jpg;
  }

  /// Decodes image bytes and bakes the EXIF orientation into the pixels,
  /// equivalent to Android's `loadCorrectedBitmap`.
  static img.Image? decodeCorrected(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    try {
      return img.bakeOrientation(decoded);
    } catch (_) {
      return decoded;
    }
  }

  /// Downscaled copy used only for fast UI display (source stays full resolution).
  static img.Image createDisplayCopy(img.Image source, {int maxSize = 1400}) {
    final longest = math.max(source.width, source.height);
    if (longest <= maxSize) return source;
    final scale = maxSize / longest;
    return img.copyResize(
      source,
      width: math.max(1, (source.width * scale).round()),
      height: math.max(1, (source.height * scale).round()),
      interpolation: img.Interpolation.linear,
    );
  }

  /// Fast JPEG encoding for preview images (no transparency needed). Much
  /// quicker than PNG for high-resolution photos.
  static Uint8List toJpegBytes(img.Image image) => img.encodeJpg(image, quality: 88);

  static Uint8List toPngBytes(img.Image image) => img.encodePng(image);

  /// Crops a rectangle (clamped like the Android implementation).
  static img.Image cropRect(
    img.Image source,
    int left,
    int top,
    int width,
    int height,
  ) {
    final safeLeft = left.clamp(0, source.width - 1);
    final safeTop = top.clamp(0, source.height - 1);
    final safeW = width.clamp(1, source.width - safeLeft);
    final safeH = height.clamp(1, source.height - safeTop);
    return img.copyCrop(
      source,
      x: safeLeft,
      y: safeTop,
      width: safeW,
      height: safeH,
    );
  }

  static img.Image scaleTo(img.Image source, int width, int height) {
    if (source.width == width && source.height == height) return source;
    return img.copyResize(
      source,
      width: math.max(1, width),
      height: math.max(1, height),
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Square / circle / triangle mask with transparent exterior.
  static img.Image applyShapeMask(img.Image source, CutShape shape) {
    if (shape == CutShape.square) return source;
    final w = source.width;
    final h = source.height;
    final out = img.Image(width: w, height: h, numChannels: 4);
    final sourceHasAlpha = source.numChannels == 4;

    // Resolve the shape geometry once instead of recomputing it per pixel.
    late final bool Function(int x, int y) isInside;
    switch (shape) {
      case CutShape.circle:
        final centerX = w / 2.0;
        final centerY = h / 2.0;
        final radius = math.min(w, h) / 2.0;
        isInside = (x, y) {
          final dx = x + 0.5 - centerX;
          final dy = y + 0.5 - centerY;
          return dx * dx + dy * dy <= radius * radius;
        };
        break;
      case CutShape.triangle:
        // Apex at top-center, base along the bottom edge.
        isInside = (x, y) {
          final nx = (x + 0.5) / w;
          final ny = (y + 0.5) / h;
          return (nx - 0.5).abs() <= ny / 2.0;
        };
        break;
      case CutShape.square:
        isInside = (_, __) => true;
        break;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!isInside(x, y)) continue;
        final p = source.getPixel(x, y);
        out.setPixel(
          x,
          y,
          img.ColorRgba8(
            _byte(p.r),
            _byte(p.g),
            _byte(p.b),
            sourceHasAlpha ? _byte(p.a) : 255,
          ),
        );
      }
    }
    return out;
  }

  /// Fine rotation (degrees) plus small 3D-style perspective skews. This is the
  /// cross-platform counterpart of Android's Camera+Matrix implementation.
  static img.Image applyFineTransform(
    img.Image source, {
    double rotationZ = 0,
    double rotationX = 0,
    double rotationY = 0,
  }) {
    if (rotationZ == 0 && rotationX == 0 && rotationY == 0) return source;
    final w = source.width;
    final h = source.height;
    final out = img.Image(width: w, height: h, numChannels: 4);
    final cx = w / 2.0;
    final cy = h / 2.0;
    final angle = -rotationZ * math.pi / 180.0;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    // Perspective amounts are intentionally subtle: rotationX tilts vertically,
    // rotationY tilts horizontally (matching the small sliders in the UI).
    final skewX = rotationY / 100.0;
    final skewY = -rotationX / 100.0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final dx = x + 0.5 - cx;
        final dy = y + 0.5 - cy;
        // undo perspective skew first
        final sx0 = dx / (1 + skewY * (dy / cy));
        final sy0 = dy / (1 + skewX * (dx / cx));
        // undo rotation
        final srcX = sx0 * cosA - sy0 * sinA + cx;
        final srcY = sx0 * sinA + sy0 * cosA + cy;
        final sample = _sampleBilinear(source, srcX, srcY);
        if (sample == null) continue;
        out.setPixel(
          x,
          y,
          img.ColorRgba8(sample.$1, sample.$2, sample.$3, sample.$4),
        );
      }
    }
    return out;
  }

  /// Best-effort port of Android's `Matrix.setPolyToPoly` 4-point warp.
  ///
  /// [points] contains 8 normalized values in the order
  /// top-left, top-right, bottom-right, bottom-left. We rectify that quad into
  /// an axis-aligned rectangle by solving a homography and inverse-mapping each
  /// output pixel with bilinear sampling.
  static img.Image apply4PointPerspectiveWarp(
    img.Image source,
    List<double> points,
  ) {
    if (points.length < 8) return source;
    final w = source.width.toDouble();
    final h = source.height.toDouble();

    final tl = Offset2(points[0] * w, points[1] * h);
    final tr = Offset2(points[2] * w, points[3] * h);
    final br = Offset2(points[4] * w, points[5] * h);
    final bl = Offset2(points[6] * w, points[7] * h);

    final topWidth = _distance(tl, tr);
    final bottomWidth = _distance(bl, br);
    final leftHeight = _distance(tl, bl);
    final rightHeight = _distance(tr, br);

    final destWidth = math.max(topWidth, bottomWidth).round().clamp(100, 10000);
    final destHeight = math.max(leftHeight, rightHeight).round().clamp(100, 10000);

    // Homography mapping destination unit square -> source quad.
    final hMatrix = _solveHomography(tl, tr, br, bl);
    if (hMatrix == null) return source;

    final out = img.Image(width: destWidth, height: destHeight, numChannels: 4);
    for (var y = 0; y < destHeight; y++) {
      final v = (y + 0.5) / destHeight;
      for (var x = 0; x < destWidth; x++) {
        final u = (x + 0.5) / destWidth;
        final denom = hMatrix[6] * u + hMatrix[7] * v + 1.0;
        if (denom.abs() < 1e-9) continue;
        final sx = (hMatrix[0] * u + hMatrix[1] * v + hMatrix[2]) / denom;
        final sy = (hMatrix[3] * u + hMatrix[4] * v + hMatrix[5]) / denom;
        final sample = _sampleBilinear(source, sx, sy);
        if (sample == null) continue;
        out.setPixel(
          x,
          y,
          img.ColorRgba8(sample.$1, sample.$2, sample.$3, sample.$4),
        );
      }
    }
    return out;
  }

  static double _distance(Offset2 a, Offset2 b) =>
      math.sqrt((a.dx - b.dx) * (a.dx - b.dx) + (a.dy - b.dy) * (a.dy - b.dy));

  /// Solves the 8x8 system mapping (0,0)(1,0)(1,1)(0,1) to the supplied quad.
  static List<double>? _solveHomography(
    Offset2 tl,
    Offset2 tr,
    Offset2 br,
    Offset2 bl,
  ) {
    final dst = [tl, tr, br, bl];
    final uv = [
      Offset2(0, 0),
      Offset2(1, 0),
      Offset2(1, 1),
      Offset2(0, 1),
    ];
    final m = List.generate(8, (_) => List<double>.filled(9, 0.0));
    for (var i = 0; i < 4; i++) {
      final u = uv[i].dx;
      final v = uv[i].dy;
      final x = dst[i].dx;
      final y = dst[i].dy;
      m[2 * i] = [u, v, 1, 0, 0, 0, -u * x, -v * x, x];
      m[2 * i + 1] = [0, 0, 0, u, v, 1, -u * y, -v * y, y];
    }
    // Gaussian elimination with partial pivoting.
    for (var col = 0; col < 8; col++) {
      var pivot = col;
      for (var row = col + 1; row < 8; row++) {
        if (m[row][col].abs() > m[pivot][col].abs()) pivot = row;
      }
      if (m[pivot][col].abs() < 1e-12) return null;
      if (pivot != col) {
        final tmp = m[pivot];
        m[pivot] = m[col];
        m[col] = tmp;
      }
      final pv = m[col][col];
      for (var j = col; j < 9; j++) m[col][j] /= pv;
      for (var row = 0; row < 8; row++) {
        if (row == col) continue;
        final factor = m[row][col];
        if (factor == 0) continue;
        for (var j = col; j < 9; j++) m[row][j] -= factor * m[col][j];
      }
    }
    return List<double>.generate(8, (i) => m[i][8]);
  }

  /// Bilinear sampler; returns null when the coordinate is outside the source.
  static (int, int, int, int)? _sampleBilinear(
    img.Image src,
    double x,
    double y,
  ) {
    final w = src.width;
    final h = src.height;
    if (x < 0 || y < 0 || x >= w - 1 || y >= h - 1) return null;
    final x0 = x.floor();
    final y0 = y.floor();
    final fx = x - x0;
    final fy = y - y0;
    final p00 = src.getPixel(x0, y0);
    final p10 = src.getPixel(x0 + 1, y0);
    final p01 = src.getPixel(x0, y0 + 1);
    final p11 = src.getPixel(x0 + 1, y0 + 1);

    double ch(num a, num b, num c, num d) =>
        a * (1 - fx) * (1 - fy) +
        b * fx * (1 - fy) +
        c * (1 - fx) * fy +
        d * fx * fy;

    final a = src.numChannels == 4;
    return (
      _byte(ch(p00.r, p10.r, p01.r, p11.r)),
      _byte(ch(p00.g, p10.g, p01.g, p11.g)),
      _byte(ch(p00.b, p10.b, p01.b, p11.b)),
      a ? _byte(ch(p00.a, p10.a, p01.a, p11.a)) : 255,
    );
  }

  static int _byte(num value) => value.round().clamp(0, 255);

  /// Compression with an optional target size (binary search over quality),
  /// equivalent to Android's `compressBitmapToBytes`.
  static Uint8List compressBitmapToBytes(
    img.Image bitmap, {
    int quality = 90,
    ExportFormat format = ExportFormat.jpg,
    int? sizeLimitKb,
  }) {
    bool isLossy(ExportFormat fmt) => switch (fmt) {
          ExportFormat.png => false,
          // Lossless WEBP ignores quality; use lossy only when a limit exists.
          ExportFormat.webp => sizeLimitKb != null && sizeLimitKb > 0,
          ExportFormat.jpg => true,
        };

    Uint8List encode(int q, {bool? lossless}) {
      switch (format) {
        case ExportFormat.png:
          return img.encodePng(bitmap);
        case ExportFormat.webp:
          return img.encodeWebP(
            bitmap,
            lossless: lossless ?? !isLossy(format),
            quality: q.clamp(0, 100),
            method: 4,
          );
        case ExportFormat.jpg:
          return img.encodeJpg(bitmap, quality: q.clamp(1, 100));
      }
    }

    if (sizeLimitKb == null || sizeLimitKb <= 0) {
      return encode(quality);
    }

    final limitBytes = sizeLimitKb * 1024;
    if (!isLossy(format)) {
      // Lossless formats: quality has no effect, encode once.
      return encode(100);
    }

    var low = 1;
    var high = 100;
    var bestBytes = encode(1, lossless: false);
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final candidate = encode(mid, lossless: false);
      if (candidate.length <= limitBytes) {
        bestBytes = candidate;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return bestBytes;
  }
}

class Offset2 {
  final double dx;
  final double dy;
  const Offset2(this.dx, this.dy);
}
