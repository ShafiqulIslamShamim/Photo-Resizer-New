/// Port of `CroppingScreen.kt` — interactive crop editor.
///
/// Pan/zoom, fine rotation, grid guides, freeform handles, shape mask preview
/// and a best-effort 4-point perspective editor, all with Flutter painters.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;

import '../controllers/photo_controller.dart';
import '../models/photo_models.dart';

class CroppingScreen extends StatefulWidget {
  final PhotoController controller;
  final VoidCallback onSettingsClick;

  const CroppingScreen({
    super.key,
    required this.controller,
    required this.onSettingsClick,
  });

  @override
  State<CroppingScreen> createState() => _CroppingScreenState();
}

class _CroppingScreenState extends State<CroppingScreen> {
  double _scale = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;

  double _startScale = 1.0;
  double _startOffsetX = 0.0;
  double _startOffsetY = 0.0;
  Offset _startFocal = Offset.zero;

  GridOption _grid = GridOption.ruleOfThirds;
  CropToolMode _mode = CropToolMode.rotation;
  double _fineRotation = 0.0;
  bool _holdingOriginal = false;

  final List<Offset> _points = [
    Offset.zero,
    const Offset(1, 0),
    const Offset(1, 1),
    const Offset(0, 1),
  ];
  int? _activeCorner;

  double _freeLeft = 0;
  double _freeTop = 0;
  double _freeRight = 1;
  double _freeBottom = 1;
  int? _activeFreeHandle;
  late double _freeStartLeft, _freeStartTop, _freeStartRight, _freeStartBottom;
  late Offset _freeStartTouch;

  static const double _toolsHeight = 270.0;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final bitmap = c.originalImage;
    if (bitmap == null) return const SizedBox.shrink();

    final targetW = int.tryParse(c.targetWidthInput) ?? bitmap.width;
    final targetH = int.tryParse(c.targetHeightInput) ?? bitmap.height;
    final targetRatio = targetW / math.max(1, targetH);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Crop & Zoom',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: c.cancelCropping,
        ),
        actions: [
          IconButton(
            key: const Key('settings_button'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: widget.onSettingsClick,
          ),
        ],
      ),
      // Compute the viewport geometry once, during the build phase, so the
      // tool bar can use it on the very first frame. The previous approach set
      // it from the viewport's LayoutBuilder (layout phase), which left it
      // uninitialized when the tool bar was built and threw a
      // LateInitializationError on first open.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight =
              (constraints.maxHeight - _toolsHeight).clamp(0.0, double.infinity).toDouble();
          final geo = _computeGeo(
            BoxConstraints(maxWidth: constraints.maxWidth, maxHeight: viewportHeight),
            bitmap,
            targetRatio,
            c,
          );
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: viewportHeight,
                child: _buildViewport(context, c, geo, colors),
              ),
              SizedBox(
                height: _toolsHeight,
                child: _buildTools(context, c, geo, colors),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Geometry (mirrors the Android BoxWithConstraints math)
  // ---------------------------------------------------------------------------
  _Geo _computeGeo(BoxConstraints constraints, img.Image bitmap, double targetRatio, PhotoController c) {
    final containerW = constraints.maxWidth;
    final containerH = constraints.maxHeight;

    final imageAspect = bitmap.width / bitmap.height;
    final containerAspect = containerW / math.max(1.0, containerH);

    late final double baseW;
    late final double baseH;
    if (imageAspect > containerAspect) {
      baseW = containerW;
      baseH = containerW / imageAspect;
    } else {
      baseH = containerH;
      baseW = containerH * imageAspect;
    }
    final x1 = (containerW - baseW) / 2;
    final y1 = (containerH - baseH) / 2;

    final isFreeform = c.selectedPresetRatio == 'Freeform';

    late final double standardW;
    late final double standardH;
    if (targetRatio > (baseW / baseH)) {
      standardW = baseW;
      standardH = baseW / targetRatio;
    } else {
      standardH = baseH;
      standardW = baseH * targetRatio;
    }

    final cropX1 = isFreeform ? x1 + _freeLeft * baseW : (containerW - standardW) / 2;
    final cropY1 = isFreeform ? y1 + _freeTop * baseH : (containerH - standardH) / 2;
    final cropX2 = isFreeform ? x1 + _freeRight * baseW : cropX1 + standardW;
    final cropY2 = isFreeform ? y1 + _freeBottom * baseH : cropY1 + standardH;
    final cropW = cropX2 - cropX1;
    final cropH = cropY2 - cropY1;

    final minScaleW = cropW / baseW;
    final minScaleH = cropH / baseH;
    final minScale = math.max(minScaleW, minScaleH);

    return _Geo(
      containerW: containerW,
      containerH: containerH,
      baseW: baseW,
      baseH: baseH,
      x1: x1,
      y1: y1,
      cropX1: cropX1,
      cropY1: cropY1,
      cropX2: cropX2,
      cropY2: cropY2,
      cropW: cropW,
      cropH: cropH,
      minScale: minScale,
      isFreeform: isFreeform,
    );
  }

  double _clampScale(double s, _Geo g) => s.clamp(g.minScale, math.max(g.minScale, 10.0));

  double _clampOffsetX(double x, double s, _Geo g) {
    final half = (g.baseW / 2) * s;
    final a = g.cropX2 - g.containerW / 2 - half;
    final b = g.cropX1 - g.containerW / 2 + half;
    return x.clamp(math.min(a, b), math.max(a, b));
  }

  double _clampOffsetY(double y, double s, _Geo g) {
    final half = (g.baseH / 2) * s;
    final a = g.cropY2 - g.containerH / 2 - half;
    final b = g.cropY1 - g.containerH / 2 + half;
    return y.clamp(math.min(a, b), math.max(a, b));
  }

  // ---------------------------------------------------------------------------
  // Viewport
  // ---------------------------------------------------------------------------
  Widget _buildViewport(BuildContext context, PhotoController c, _Geo g, ColorScheme colors) {
    _scale = _clampScale(_scale, g);
    _offsetX = _clampOffsetX(_offsetX, _scale, g);
    _offsetY = _clampOffsetY(_offsetY, _scale, g);

    final bytes = c.originalDisplayBytes;
    final isPerspective = _mode == CropToolMode.perspective4d;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        final p = d.localFocalPoint;
        if (isPerspective) {
          _activeCorner = _nearestCorner(p, g);
        } else if (g.isFreeform) {
          _activeFreeHandle = _nearestFreeHandle(p, g);
          if (_activeFreeHandle != null) {
            _freeStartLeft = _freeLeft;
            _freeStartTop = _freeTop;
            _freeStartRight = _freeRight;
            _freeStartBottom = _freeBottom;
            _freeStartTouch = p;
          }
        } else {
          _startScale = _scale;
          _startOffsetX = _offsetX;
          _startOffsetY = _offsetY;
          _startFocal = p;
        }
      },
      onScaleUpdate: (d) {
        final p = d.localFocalPoint;
        if (isPerspective) {
          if (_activeCorner != null) {
            final nx = ((p.dx - g.x1) / g.baseW).clamp(0.0, 1.0);
            final ny = ((p.dy - g.y1) / g.baseH).clamp(0.0, 1.0);
            setState(() => _points[_activeCorner!] = Offset(nx, ny));
          }
          return;
        }
        if (g.isFreeform && _activeFreeHandle != null) {
          _updateFreeform(p, g);
          return;
        }
        final target = _clampScale(_startScale * d.scale, g);
        final actualZoom = _startScale > 0 ? target / _startScale : 1.0;
        final cX = g.containerW / 2;
        final cY = g.containerH / 2;
        final fx = _startFocal.dx;
        final fy = _startFocal.dy;
        final panX = p.dx - fx;
        final panY = p.dy - fy;
        setState(() {
          _scale = target;
          _offsetX = _clampOffsetX(
            (_startOffsetX - (fx - cX)) * actualZoom + (fx - cX) + panX,
            target,
            g,
          );
          _offsetY = _clampOffsetY(
            (_startOffsetY - (fy - cY)) * actualZoom + (fy - cY) + panY,
            target,
            g,
          );
        });
      },
      onScaleEnd: (_) {
        _activeCorner = null;
        _activeFreeHandle = null;
      },
      onLongPressStart: (_) {
        if (isPerspective) setState(() => _holdingOriginal = true);
      },
      onLongPressEnd: (_) {
        if (_holdingOriginal) setState(() => _holdingOriginal = false);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Transform(
              alignment: Alignment.center,
              transform: isPerspective
                  ? Matrix4.identity()
                  : (Matrix4.identity()
                    ..translate(_offsetX, _offsetY)
                    ..scale(_scale)
                    ..rotateZ((_fineRotation / 100) * 45 * math.pi / 180)),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          CustomPaint(
            painter: _CropPainter(
              geo: g,
              grid: _grid,
              shape: c.selectedCutShape,
              mode: _mode,
              points: _points,
              showHandles: isPerspective && !_holdingOriginal,
            ),
            size: Size(g.containerW, g.containerH),
          ),
        ],
      ),
    );
  }

  int? _nearestCorner(Offset p, _Geo g) {
    final screenPoints = _perspectiveScreenPoints(g);
    var best = 0;
    var bestDist = double.maxFinite;
    for (var i = 0; i < 4; i++) {
      final d = (p - screenPoints[i]).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return bestDist <= 48 ? best : null;
  }

  List<Offset> _perspectiveScreenPoints(_Geo g) => _points
      .map((p) => Offset(g.x1 + p.dx * g.baseW, g.y1 + p.dy * g.baseH))
      .toList();

  int? _nearestFreeHandle(Offset p, _Geo g) {
    final list = [
      Offset(g.cropX1, g.cropY1),
      Offset(g.cropX2, g.cropY1),
      Offset(g.cropX2, g.cropY2),
      Offset(g.cropX1, g.cropY2),
    ];
    for (var i = 0; i < 4; i++) {
      if ((p - list[i]).distance <= 48) return i;
    }
    if (p.dx >= g.cropX1 &&
        p.dx <= g.cropX2 &&
        p.dy >= g.cropY1 &&
        p.dy <= g.cropY2) {
      return 8;
    }
    return null;
  }

  void _updateFreeform(Offset pos, _Geo g) {
    const minSize = 0.05;
    final normX = ((pos.dx - g.x1) / g.baseW).clamp(0.0, 1.0);
    final normY = ((pos.dy - g.y1) / g.baseH).clamp(0.0, 1.0);
    setState(() {
      switch (_activeFreeHandle) {
        case 8:
          final dx = (pos.dx - _freeStartTouch.dx) / g.baseW;
          final dy = (pos.dy - _freeStartTouch.dy) / g.baseH;
          final w = _freeStartRight - _freeStartLeft;
          final h = _freeStartBottom - _freeStartTop;
          final nl = (_freeStartLeft + dx).clamp(0.0, 1.0 - w);
          final nt = (_freeStartTop + dy).clamp(0.0, 1.0 - h);
          _freeLeft = nl;
          _freeRight = nl + w;
          _freeTop = nt;
          _freeBottom = nt + h;
        case 0:
          _freeLeft = math.min(normX, _freeStartRight - minSize);
          _freeTop = math.min(normY, _freeStartBottom - minSize);
        case 1:
          _freeRight = math.max(normX, _freeStartLeft + minSize);
          _freeTop = math.min(normY, _freeStartBottom - minSize);
        case 2:
          _freeRight = math.max(normX, _freeStartLeft + minSize);
          _freeBottom = math.max(normY, _freeStartTop + minSize);
        case 3:
          _freeLeft = math.min(normX, _freeStartRight - minSize);
          _freeBottom = math.max(normY, _freeStartTop + minSize);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Tools area
  // ---------------------------------------------------------------------------
  Widget _buildTools(BuildContext context, PhotoController c, _Geo geo, ColorScheme colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16, top: 8),
          color: Colors.black,
          width: double.infinity,
          child: _mode == CropToolMode.perspective4d
              ? _perspectiveTools(context, c, colors)
              // The Container adds 16 dp of padding on each side; subtract it
              // so the ruler never overflows the tool bar.
              : _regularTools(context, c, geo, colors, constraints.maxWidth - 32),
        );
      },
    );
  }

  Widget _perspectiveTools(BuildContext context, PhotoController c, ColorScheme colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onLongPressStart: (_) => setState(() => _holdingOriginal = true),
          onLongPressEnd: (_) => setState(() => _holdingOriginal = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Tap and hold to see original',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _circleIconButton(
              icon: Icons.close,
              color: Colors.grey.shade800,
              onTap: () => setState(() => _mode = CropToolMode.rotation),
            ),
            InkWell(
              onTap: () => setState(() {
                _points[0] = Offset.zero;
                _points[1] = const Offset(1, 0);
                _points[2] = const Offset(1, 1);
                _points[3] = const Offset(0, 1);
              }),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Reset',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            _circleIconButton(
              icon: Icons.check,
              color: colors.primary,
              testKey: 'confirm_crop_button',
              onTap: () {
                c.confirmCropAndProcess(
                  pixelLeft: 0,
                  pixelTop: 0,
                  croppedW: c.originalImage!.width,
                  croppedH: c.originalImage!.height,
                  perspectivePoints: [
                    _points[0].dx, _points[0].dy,
                    _points[1].dx, _points[1].dy,
                    _points[2].dx, _points[2].dy,
                    _points[3].dx, _points[3].dy,
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _regularTools(
    BuildContext context,
    PhotoController c,
    _Geo g,
    ColorScheme colors,
    double toolsWidth,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_mode == CropToolMode.grid)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF212121),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    for (final option in GridOption.values)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _grid = option),
                          child: Container(
                            height: 40,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _grid == option
                                  ? colors.primary
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              option.label,
                              style: TextStyle(
                                color: _grid == option ? Colors.white : Colors.grey.shade300,
                                fontSize: 11,
                                fontWeight: _grid == option ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (_mode != CropToolMode.grid)
              _RulerSlider(
                value: _mode == CropToolMode.rotation ? _fineRotation : _scale,
                valueRange: _mode == CropToolMode.rotation
                    ? const [-100.0, 100.0]
                    : [g.minScale, math.max(g.minScale, 10.0)],
                isZoom: _mode == CropToolMode.zoom,
                width: toolsWidth,
                onChanged: (value) {
                  setState(() {
                    if (_mode == CropToolMode.rotation) {
                      _fineRotation = value;
                    } else {
                      final next = _clampScale(value, g);
                      final ratio = _scale > 0 ? next / _scale : 1.0;
                      _scale = next;
                      _offsetX = _clampOffsetX(_offsetX * ratio, next, g);
                      _offsetY = _clampOffsetY(_offsetY * ratio, next, g);
                    }
                  });
                },
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolTab(
                  icon: Icons.rotate_right,
                  label: 'Rotate',
                  active: _mode == CropToolMode.rotation,
                  colors: colors,
                  onTap: () => setState(() => _mode = CropToolMode.rotation),
                ),
                _toolTab(
                  icon: Icons.zoom_in,
                  label: 'Zoom',
                  active: _mode == CropToolMode.zoom,
                  colors: colors,
                  onTap: () => setState(() => _mode = CropToolMode.zoom),
                ),
                _toolTab(
                  icon: Icons.aspect_ratio,
                  label: 'Perspective',
                  active: _mode == CropToolMode.perspective4d,
                  colors: colors,
                  onTap: () => setState(() => _mode = CropToolMode.perspective4d),
                ),
                _toolTab(
                  icon: Icons.grid_on,
                  label: 'Grid',
                  active: _mode == CropToolMode.grid,
                  colors: colors,
                  onTap: () => setState(() => _mode = CropToolMode.grid),
                ),
                _toolTab(
                  icon: Icons.rotate_right,
                  label: '90°',
                  active: false,
                  colors: colors,
                  inactiveColor: Colors.grey,
                  onTap: c.rotateOriginal,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _circleIconButton(
                  icon: Icons.close,
                  color: Colors.grey.shade800,
                  onTap: c.cancelCropping,
                ),
                const Text(
                  'Framing',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                _circleIconButton(
                  icon: Icons.check,
                  color: colors.primary,
                  activeColor: colors.onPrimary,
                  testKey: 'confirm_crop_button',
                  onTap: () => _confirmCrop(c, g),
                ),
              ],
            ),
          ],
        );
  }

  void _confirmCrop(PhotoController c, _Geo g) {
    final bitmap = c.originalImage!;
    final srcX1 = (g.cropX1 - g.containerW / 2 - _offsetX) / _scale + g.containerW / 2;
    final srcY1 = (g.cropY1 - g.containerH / 2 - _offsetY) / _scale + g.containerH / 2;
    final srcX2 = (g.cropX2 - g.containerW / 2 - _offsetX) / _scale + g.containerW / 2;
    final srcY2 = (g.cropY2 - g.containerH / 2 - _offsetY) / _scale + g.containerH / 2;
    final relX1 = srcX1 - g.x1;
    final relY1 = srcY1 - g.y1;
    final relX2 = srcX2 - g.x1;
    final relY2 = srcY2 - g.y1;
    final pxLeft = ((relX1 / g.baseW) * bitmap.width).round().clamp(0, bitmap.width);
    final pxTop = ((relY1 / g.baseH) * bitmap.height).round().clamp(0, bitmap.height);
    final pxRight = ((relX2 / g.baseW) * bitmap.width).round().clamp(0, bitmap.width);
    final pxBottom = ((relY2 / g.baseH) * bitmap.height).round().clamp(0, bitmap.height);
    c.confirmCropAndProcess(
      pixelLeft: pxLeft,
      pixelTop: pxTop,
      croppedW: math.max(1, pxRight - pxLeft),
      croppedH: math.max(1, pxBottom - pxTop),
      fineRotation: (_fineRotation / 100) * 45,
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color? activeColor,
    String? testKey,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: InkWell(
        key: testKey == null ? null : Key(testKey),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: activeColor ?? Colors.white),
        ),
      ),
    );
  }

  Widget _toolTab({
    required IconData icon,
    required String label,
    required bool active,
    required ColorScheme colors,
    required VoidCallback onTap,
    Color? inactiveColor,
  }) {
    final color = active ? colors.primary : (inactiveColor ?? Colors.grey);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom painter for the crop overlay.
// ---------------------------------------------------------------------------
class _Geo {
  final double containerW, containerH, baseW, baseH, x1, y1;
  final double cropX1, cropY1, cropX2, cropY2, cropW, cropH, minScale;
  final bool isFreeform;

  const _Geo({
    required this.containerW,
    required this.containerH,
    required this.baseW,
    required this.baseH,
    required this.x1,
    required this.y1,
    required this.cropX1,
    required this.cropY1,
    required this.cropX2,
    required this.cropY2,
    required this.cropW,
    required this.cropH,
    required this.minScale,
    required this.isFreeform,
  });
}

class _CropPainter extends CustomPainter {
  final _Geo geo;
  final GridOption grid;
  final CutShape shape;
  final CropToolMode mode;
  final List<Offset> points;
  final bool showHandles;

  const _CropPainter({
    required this.geo,
    required this.grid,
    required this.shape,
    required this.mode,
    required this.points,
    required this.showHandles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == CropToolMode.perspective4d) {
      _paintPerspective(canvas);
      return;
    }
    final hole = _holePath(geo, shape);
    final full = Rect.fromLTWH(0, 0, geo.containerW, geo.containerH);

    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, Paint()..color = Colors.black.withValues(alpha: 0.7));
    canvas.drawPath(hole, Paint()..blendMode = BlendMode.clear..style = PaintingStyle.fill);
    canvas.restore();

    canvas.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = Colors.white,
    );
    _drawGrid(canvas);
    _drawCorners(canvas);
    if (geo.isFreeform) {
      for (final p in [
        Offset(geo.cropX1, geo.cropY1),
        Offset(geo.cropX2, geo.cropY1),
        Offset(geo.cropX2, geo.cropY2),
        Offset(geo.cropX1, geo.cropY2),
      ]) {
        canvas.drawCircle(p, 11, Paint()..color = const Color(0xFFE3B505));
        canvas.drawCircle(p, 7.5, Paint()..color = Colors.white);
      }
    }
  }

  Path _holePath(_Geo g, CutShape shape) {
    final path = Path();
    switch (shape) {
      case CutShape.circle:
        final radius = math.min(g.cropW, g.cropH) / 2;
        path.addOval(Rect.fromCircle(
          center: Offset(g.cropX1 + g.cropW / 2, g.cropY1 + g.cropH / 2),
          radius: radius,
        ));
        break;
      case CutShape.triangle:
        path.moveTo(g.cropX1 + g.cropW / 2, g.cropY1);
        path.lineTo(g.cropX2, g.cropY2);
        path.lineTo(g.cropX1, g.cropY2);
        path.close();
        break;
      case CutShape.square:
        path.addRect(Rect.fromLTWH(g.cropX1, g.cropY1, g.cropW, g.cropH));
        break;
    }
    return path;
  }

  void _drawGrid(Canvas canvas) {
    if (grid == GridOption.none) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 3;
    final x1 = geo.cropX1, y1 = geo.cropY1, x2 = geo.cropX2, y2 = geo.cropY2;
    final w = geo.cropW, h = geo.cropH;

    void vertical(double f) => canvas.drawLine(Offset(x1 + w * f, y1), Offset(x1 + w * f, y2), paint);
    void horizontal(double f) => canvas.drawLine(Offset(x1, y1 + h * f), Offset(x2, y1 + h * f), paint);

    switch (grid) {
      case GridOption.ruleOfThirds:
        vertical(1 / 3);
        vertical(2 / 3);
        horizontal(1 / 3);
        horizontal(2 / 3);
        break;
      case GridOption.goldenRatio:
        vertical(0.382);
        vertical(0.618);
        horizontal(0.382);
        horizontal(0.618);
        break;
      case GridOption.fourByFour:
        vertical(0.25);
        vertical(0.5);
        vertical(0.75);
        horizontal(0.25);
        horizontal(0.5);
        horizontal(0.75);
        break;
      case GridOption.none:
        break;
    }
  }

  void _drawCorners(Canvas canvas) {
    final paint = Paint()..color = Colors.white..strokeWidth = 4;
    const len = 20.0;
    final x1 = geo.cropX1, y1 = geo.cropY1, x2 = geo.cropX2, y2 = geo.cropY2;
    canvas.drawLine(Offset(x1, y1), Offset(x1 + len, y1), paint);
    canvas.drawLine(Offset(x1, y1), Offset(x1, y1 + len), paint);
    canvas.drawLine(Offset(x2, y1), Offset(x2 - len, y1), paint);
    canvas.drawLine(Offset(x2, y1), Offset(x2, y1 + len), paint);
    canvas.drawLine(Offset(x1, y2), Offset(x1 + len, y2), paint);
    canvas.drawLine(Offset(x1, y2), Offset(x1, y2 - len), paint);
    canvas.drawLine(Offset(x2, y2), Offset(x2 - len, y2), paint);
    canvas.drawLine(Offset(x2, y2), Offset(x2, y2 - len), paint);
  }

  void _paintPerspective(Canvas canvas) {
    final g = geo;
    final screen = points
        .map((p) => Offset(g.x1 + p.dx * g.baseW, g.y1 + p.dy * g.baseH))
        .toList();
    final path = Path()
      ..moveTo(screen[0].dx, screen[0].dy)
      ..lineTo(screen[1].dx, screen[1].dy)
      ..lineTo(screen[2].dx, screen[2].dy)
      ..lineTo(screen[3].dx, screen[3].dy)
      ..close();
    final full = Rect.fromLTWH(0, 0, g.containerW, g.containerH);
    if (!showHandles) return;
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, Paint()..color = Colors.black.withValues(alpha: 0.65));
    canvas.drawPath(path, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    for (final p in screen) {
      canvas.drawCircle(p, 13.5, Paint()..color = Colors.black.withValues(alpha: 0.35));
      canvas.drawCircle(p, 11, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) => true;
}

// ---------------------------------------------------------------------------
// Ruler slider (Google Photos style dial)
// ---------------------------------------------------------------------------
class _RulerSlider extends StatelessWidget {
  final double value;
  final List<double> valueRange;
  final bool isZoom;
  final double width;
  final ValueChanged<double> onChanged;

  const _RulerSlider({
    required this.value,
    required this.valueRange,
    required this.isZoom,
    required this.width,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final pxPerUnit = isZoom ? width / 12 : 2.5;
        final delta = -(d.delta.dx / pxPerUnit);
        onChanged((value + delta).clamp(valueRange[0], valueRange[1]));
      },
      onTapUp: (d) {
        final localX = d.localPosition.dx;
        if (localX < 90) {
          onChanged(isZoom ? 1.0 : 0.0);
        }
      },
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF212121),
          borderRadius: BorderRadius.circular(29),
        ),
        child: Stack(
          children: [
            CustomPaint(
              painter: _RulerPainter(
                value: value,
                range: valueRange,
                isZoom: isZoom,
                width: width,
              ),
              size: Size(width, 58),
            ),
            Positioned(
              left: 16,
              top: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isZoom ? '${value.toStringAsFixed(1)}x' : _signed(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _signed(double v) {
    final i = v.round();
    return i > 0 ? '+$i' : '$i';
  }
}

class _RulerPainter extends CustomPainter {
  final double value;
  final List<double> range;
  final bool isZoom;
  final double width;

  const _RulerPainter({
    required this.value,
    required this.range,
    required this.isZoom,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = width / 2;
    final h = size.height;
    final start = range[0];
    final end = range[1];

    void tick(double v, bool major) {
      final x = centerX + (v - value) * (isZoom ? width / 12 : 2.5);
      if (x < 0 || x > width) return;
      final tickH = major ? 22.0 : 14.0;
      final alpha = (1 - ((x - centerX).abs() / (width / 2))).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(x, (h - tickH) / 2),
        Offset(x, (h + tickH) / 2),
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.45)
          ..strokeWidth = major ? 1.5 : 1,
      );
    }

    if (isZoom) {
      const step = 0.5;
      final minT = (start / step).floor();
      final maxT = (end / step).ceil();
      for (var t = minT; t <= maxT; t++) {
        tick(t * step, t % 2 == 0);
      }
    } else {
      final visible = (width / 2) / 2.5;
      final minV = math.max((value - visible).floor(), start.round());
      final maxV = math.min((value + visible).ceil(), end.round());
      for (var v = minV; v <= maxV; v++) {
        if (v.isOdd) continue;
        tick(v.toDouble(), v % 10 == 0);
      }
    }

    canvas.drawLine(
      Offset(centerX, (h - 34) / 2),
      Offset(centerX, (h + 34) / 2),
      Paint()
        ..color = const Color(0xFFE3B505)
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) => true;
}
