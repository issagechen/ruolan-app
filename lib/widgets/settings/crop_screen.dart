import "dart:math";
import "dart:typed_data";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";

class CropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final double aspectRatio; // width / height
  final String title;

  const CropScreen({
    super.key,
    required this.imageBytes,
    required this.aspectRatio,
    this.title = "裁剪图片",
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final TransformationController _transformCtrl = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  bool _loading = true;
  ui.Image? _image;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    _image = frame.image;
    _imageSize = Size(_image!.width.toDouble(), _image!.height.toDouble());
    setState(() => _loading = false);
  }

  Future<Uint8List?> _cropAndSave() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || _image == null) return null;

      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final captured = await boundary.toImage(pixelRatio: pixelRatio);

      final renderBox = _repaintKey.currentContext!.findRenderObject() as RenderBox;
      final viewSize = renderBox.size;
      final cropH = viewSize.height;
      final cropW = cropH * widget.aspectRatio;

      final cropRect = Rect.fromCenter(
        center: Offset(viewSize.width / 2 * pixelRatio, viewSize.height / 2 * pixelRatio),
        width: cropW * pixelRatio,
        height: cropH * pixelRatio,
      );

      final imgRect = Offset.zero & Size(captured.width.toDouble(), captured.height.toDouble());
      final safeRect = cropRect.intersect(imgRect);
      if (safeRect.isEmpty) return null;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.translate(-safeRect.left, -safeRect.top);
      canvas.drawImage(captured, Offset.zero, Paint());
      final picture = recorder.endRecording();

      final cropped = await picture.toImage(safeRect.width.toInt(), safeRect.height.toInt());
      final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
      captured.dispose();
      cropped.dispose();

      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final result = await _cropAndSave();
              if (navigator.mounted) navigator.pop(result);
            },
            child: const Text("确认", style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(child: LayoutBuilder(builder: (context, constraints) {
              final viewW = constraints.maxWidth;
              final viewH = constraints.maxHeight;

              // Crop frame fills full viewport height
              final cropH = viewH;
              final cropW = cropH * widget.aspectRatio;

              final imgW = _imageSize!.width;
              final imgH = _imageSize!.height;

              // Scale image larger than crop frame for panning room
              final fitScale = max(cropW / imgW, cropH / imgH).clamp(0.3, 4.0);
              final panScale = fitScale * 1.5;
              final displayW = imgW * panScale;
              final displayH = imgH * panScale;

              // Center the image initially
              final initDx = (viewW - displayW) / 2;
              final initDy = (viewH - displayH) / 2;

              WidgetsBinding.instance.addPostFrameCallback((_) {
              final matrix = Matrix4.identity()
                ..translateByDouble(initDx, initDy, 0.0, 1.0)
                ..scaleByDouble(panScale, panScale, panScale, 1.0);
                _transformCtrl.value = matrix;
              });

              return Stack(
                children: [
                  RepaintBoundary(
                    key: _repaintKey,
                    child: SizedBox(
                      width: viewW,
                      height: viewH,
                      child: InteractiveViewer(
                        transformationController: _transformCtrl,
                        constrained: false,
                        minScale: 0.10,
                        maxScale: 6.0,
                        child: SizedBox(
                          width: imgW,
                          height: imgH,
                          child: RawImage(image: _image, fit: BoxFit.fill),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size(viewW, viewH),
                      painter: _CropOverlayPainter(aspectRatio: widget.aspectRatio),
                    ),
                  ),
                ],
              );
            })),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final double aspectRatio;
  _CropOverlayPainter({required this.aspectRatio});

  @override
  void paint(Canvas canvas, Size size) {
    // Crop rect fills full height
    final h = size.height;
    final w = h * aspectRatio;

    final cropRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );

    final path = Path()..addRect(Offset.zero & size);
    final cropPath = Path()..addRect(cropRect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, path, cropPath),
      Paint()..color = Colors.black54,
    );

    canvas.drawRect(cropRect, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) => aspectRatio != old.aspectRatio;
}