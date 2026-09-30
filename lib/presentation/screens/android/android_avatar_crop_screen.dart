import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Crop math, in "circle units": the crop circle's diameter is 1. [pan] is
/// the image centre's offset from the circle centre; [zoom] 1.0 means the
/// image's short side exactly spans the circle.
class AvatarCropMath {
  static const minZoom = 1.0, maxZoom = 3.0;

  static Size rotated(Size image, int turns) =>
      turns.isOdd ? image.flipped : image;

  /// Image pixels → circle units.
  static double unitScale(Size rotatedImage, double zoom) =>
      zoom / rotatedImage.shortestSide;

  /// Keeps the circle's bounding square fully covered by the image.
  static Offset clampPan(Offset pan, Size rotatedImage, double zoom) {
    final k = unitScale(rotatedImage, zoom);
    final mx = (rotatedImage.width * k - 1) / 2;
    final my = (rotatedImage.height * k - 1) / 2;
    return Offset(pan.dx.clamp(-mx, mx), pan.dy.clamp(-my, my));
  }

  /// The circle's bounding square in rotated-image pixel coordinates.
  static Rect sourceRect(Size rotatedImage, double zoom, Offset pan) {
    final k = unitScale(rotatedImage, zoom);
    return Rect.fromCenter(
      center: Offset(rotatedImage.width / 2 - pan.dx / k,
          rotatedImage.height / 2 - pan.dy / k),
      width: 1 / k,
      height: 1 / k,
    );
  }
}

/// Android "Adjust your photo" (canvas: AndroidAvatar). Always Dusk-dark.
/// Pops with the cropped square PNG bytes, or null on cancel.
class AndroidAvatarCropScreen extends StatefulWidget {
  final XFile initial;

  const AndroidAvatarCropScreen({super.key, required this.initial});

  static Future<XFile?> _pick() => ImagePicker()
      .pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048);

  /// Picks from the gallery, then lets the user frame it.
  static Future<Uint8List?> pickAndCrop(BuildContext context) async {
    final file = await _pick();
    if (file == null || !context.mounted) return null;
    return Navigator.of(context).push<Uint8List>(MaterialPageRoute(
        builder: (_) => AndroidAvatarCropScreen(initial: file)));
  }

  @override
  State<AndroidAvatarCropScreen> createState() =>
      _AndroidAvatarCropScreenState();
}

class _AndroidAvatarCropScreenState extends State<AndroidAvatarCropScreen> {
  static const _c = WandererColors.dark;
  static const _sliderAccent = Color(0xFFE8702A);
  static const _outputSize = 768;

  ui.Image? _image;
  double _zoom = 1;
  Offset _pan = Offset.zero;
  int _turns = 0;
  double _gestureStartZoom = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load(widget.initial);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load(XFile file) async {
    // The platform decoder applies EXIF orientation.
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) return frame.image.dispose();
    setState(() {
      _image?.dispose();
      _image = frame.image;
      _zoom = 1;
      _pan = Offset.zero;
      _turns = 0;
    });
  }

  Size get _rotated => AvatarCropMath.rotated(
      Size(_image!.width.toDouble(), _image!.height.toDouble()), _turns);

  void _set({double? zoom, Offset? pan, int? turns}) {
    if (_image == null) return;
    setState(() {
      _zoom = (zoom ?? _zoom)
          .clamp(AvatarCropMath.minZoom, AvatarCropMath.maxZoom)
          .toDouble();
      _turns = turns ?? _turns;
      _pan = AvatarCropMath.clampPan(pan ?? _pan, _rotated, _zoom);
    });
  }

  Future<void> _chooseAnother() async {
    final file = await AndroidAvatarCropScreen._pick();
    if (file != null) await _load(file);
  }

  Future<void> _use() async {
    final image = _image;
    if (image == null || _saving) return;
    setState(() => _saving = true);
    final src = AvatarCropMath.sourceRect(_rotated, _zoom, _pan);
    final n = math.min(_outputSize, math.max(1, src.width.round()));
    final recorder = ui.PictureRecorder();
    _PhotoPainter(image, _turns, src, 1)
        .paint(Canvas(recorder), Size.square(n.toDouble()));
    final out = await recorder.endRecording().toImage(n, n);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    if (mounted) Navigator.pop(context, data!.buffer.asUint8List());
  }

  Widget _roundButton(IconData icon, String label, VoidCallback onTap) =>
      Material(
        color: _c.raised,
        shape: CircleBorder(side: BorderSide(color: _c.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, size: 18, color: _c.text, semanticLabel: label),
          ),
        ),
      );

  Widget _preview(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _c.line, width: 2),
        ),
        child: ClipOval(child: _photo(1)),
      );

  Widget _photo(double circleFraction) => _image == null
      ? const SizedBox.expand()
      : CustomPaint(
          size: Size.infinite,
          painter: _PhotoPainter(_image!, _turns,
              AvatarCropMath.sourceRect(_rotated, _zoom, _pan), circleFraction),
        );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = TextStyle(fontFamily: WandererTheme.bodyFont, color: _c.text);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _c.ground,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    IconButton(
                      icon: Icon(Icons.close, size: 22, color: _c.text),
                      tooltip: l10n.cancel,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(l10n.avatarAdjustTitle,
                          style: WandererTheme.display(20, color: _c.text)),
                    ),
                  ]),
                ),
              ),
              Expanded(child: LayoutBuilder(builder: (context, box) {
                final side = math.min(box.maxWidth, box.maxHeight - 40);
                final circle = side * 340 / 412;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: side,
                      child: ClipRect(
                        child: GestureDetector(
                          onScaleStart: (_) => _gestureStartZoom = _zoom,
                          onScaleUpdate: (d) => _set(
                            zoom: _gestureStartZoom * d.scale,
                            pan: _pan + d.focalPointDelta / circle,
                          ),
                          child: Stack(fit: StackFit.expand, children: [
                            _image == null
                                ? Center(
                                    child: CircularProgressIndicator(
                                        color: WandererTheme.trail))
                                : _photo(340 / 412),
                            IgnorePointer(
                              child: CustomPaint(
                                  painter: _MaskPainter(_c.ground, _c.text)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(l10n.avatarAdjustHint,
                        style: body.copyWith(fontSize: 13, color: _c.caption)),
                  ],
                );
              })),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                decoration: BoxDecoration(
                  color: _c.surface,
                  border: Border(top: BorderSide(color: _c.line)),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: DefaultTextStyle(
                  style: body,
                  child: Column(children: [
                    Row(children: [
                      _roundButton(Icons.remove, l10n.avatarZoomOut,
                          () => _set(zoom: _zoom - 0.2)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: _sliderAccent,
                            thumbColor: _sliderAccent,
                            inactiveTrackColor: _c.line,
                            overlayColor: _sliderAccent.withOpacity(0.16),
                          ),
                          child: Slider(
                            value: _zoom,
                            min: AvatarCropMath.minZoom,
                            max: AvatarCropMath.maxZoom,
                            onChanged: (v) => _set(zoom: v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      _roundButton(Icons.add, l10n.avatarZoomIn,
                          () => _set(zoom: _zoom + 0.2)),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      _preview(44),
                      const SizedBox(width: 10),
                      _preview(28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l10n.avatarPreviewCaption,
                            style: TextStyle(
                                fontSize: 12, height: 1.3, color: _c.caption)),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: () => _set(turns: (_turns + 1) % 4),
                          icon: const Icon(Icons.rotate_right, size: 16),
                          label: Text(l10n.avatarRotate),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _c.text,
                            backgroundColor: _c.raised,
                            side: BorderSide(color: _c.line),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _set(zoom: 1, pan: Offset.zero, turns: 0),
                        style: TextButton.styleFrom(
                          foregroundColor: _c.accentText,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: Text(l10n.avatarReset),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _saving ? null : _chooseAnother,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _c.text,
                            side: BorderSide(color: _c.line),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          child: Text(l10n.avatarChooseAnother),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: _image == null || _saving ? null : _use,
                            style: FilledButton.styleFrom(
                              backgroundColor: WandererTheme.trail,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            child: Text(l10n.avatarUseThis),
                          ),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints [src] (rotated-image pixels) into a centred square that spans
/// [circleFraction] of the canvas width; the rest of the image spills around
/// it. Shared by the stage, the previews and the final export.
class _PhotoPainter extends CustomPainter {
  final ui.Image image;
  final int turns;
  final Rect src;
  final double circleFraction;

  _PhotoPainter(this.image, this.turns, this.src, this.circleFraction);

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.width * circleFraction;
    final w = image.width.toDouble(), h = image.height.toDouble();
    final rotated = AvatarCropMath.rotated(Size(w, h), turns);
    canvas
      ..save()
      ..translate((size.width - d) / 2, (size.height - d) / 2)
      ..scale(d / src.width)
      ..translate(-src.left + rotated.width / 2, -src.top + rotated.height / 2)
      ..rotate(turns * math.pi / 2)
      ..drawImage(image, Offset(-w / 2, -h / 2),
          Paint()..filterQuality = FilterQuality.high)
      ..restore();
  }

  @override
  bool shouldRepaint(_PhotoPainter old) =>
      old.image != image ||
      old.turns != turns ||
      old.src != src ||
      old.circleFraction != circleFraction;
}

/// Dims everything outside the crop circle and outlines it.
class _MaskPainter extends CustomPainter {
  final Color dim, outline;

  _MaskPainter(this.dim, this.outline);

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.width * 170 / 412);
    canvas
      ..drawPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(Offset.zero & size)
            ..addOval(circle),
          Paint()..color = dim.withOpacity(0.72))
      ..drawOval(
          circle,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = outline);
  }

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.dim != dim || old.outline != outline;
}
