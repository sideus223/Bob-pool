import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Presentation frame only: the captured app pixels are drawn without changes.
const _phoneSize = Size(438, 960);

void _text(Canvas canvas, String text, Offset offset, double size) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF202124),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
  painter.dispose();
}

void _phone(Canvas canvas, ui.Image screenshot) {
  final paint = Paint()..isAntiAlias = true;
  final shell = RRect.fromRectAndRadius(
    const Rect.fromLTWH(16, 12, 406, 936),
    const Radius.circular(44),
  );
  canvas.drawShadow(Path()..addRRect(shell), Colors.black26, 8, true);
  canvas.drawRRect(shell, paint..color = const Color(0xFF202124));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(422, 156, 3, 62),
      const Radius.circular(2),
    ),
    paint,
  );
  canvas.save();
  canvas.clipRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(24, 20, 390, 920),
      const Radius.circular(36),
    ),
  );
  canvas.drawColor(Colors.white, BlendMode.srcOver);
  _text(canvas, '10:08', const Offset(42, 29), 12);
  canvas.drawCircle(const Offset(219, 39), 4.5, paint);
  for (var i = 0; i < 4; i++) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(350 + i * 4, 43 - i * 2, 2.5, 4 + i * 2),
        const Radius.circular(0.7),
      ),
      paint,
    );
  }
  canvas.drawArc(
    const Rect.fromLTWH(372, 33, 14, 12),
    3.8,
    1.8,
    false,
    Paint()
      ..color = const Color(0xFF202124)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  canvas.drawCircle(const Offset(379, 43), 1.5, paint);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(392, 34, 7, 11),
      const Radius.circular(1.2),
    ),
    paint,
  );
  canvas.drawRect(const Rect.fromLTWH(394, 32, 3, 2), paint);
  canvas.drawImageRect(
    screenshot,
    Rect.fromLTWH(
      0,
      0,
      screenshot.width.toDouble(),
      screenshot.height.toDouble(),
    ),
    const Rect.fromLTWH(24, 60, 390, 844),
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(188, 924, 62, 4),
      const Radius.circular(2),
    ),
    paint..color = const Color(0xFF93969B),
  );
  canvas.restore();
}

Future<void> _save(ui.Picture picture, Size size, String path) async {
  final image = await picture.toImage(size.width.ceil(), size.height.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

Future<void> writePhonePreview(ui.Image screenshot, String path) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(2);
  _phone(canvas, screenshot);
  await _save(recorder.endRecording(), _phoneSize * 2, path);
}

Future<void> writePhoneOverview(
  String directory,
  String name,
  List<(String, String)> screens,
) async {
  const gap = 90.0;
  const padding = 40.0;
  const top = 74.0;
  final size = Size(
    padding * 2 +
        screens.length * _phoneSize.width +
        (screens.length - 1) * gap,
    top + _phoneSize.height + 28,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFF6F7F9), BlendMode.src);
  final images = <ui.Image>[];
  for (var index = 0; index < screens.length; index++) {
    final (file, title) = screens[index];
    final codec = await ui.instantiateImageCodec(
      await File('$directory/$file.png').readAsBytes(),
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    images.add(image);
    final left = padding + index * (_phoneSize.width + gap);
    final label = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          fontFamily: 'NotoSansKR',
          color: Color(0xFF202124),
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(left + (_phoneSize.width - label.width) / 2, 26),
    );
    label.dispose();
    canvas.save();
    canvas.translate(left, top);
    _phone(canvas, image);
    canvas.restore();
  }
  await _save(recorder.endRecording(), size, '$directory/$name.png');
  for (final image in images) {
    image.dispose();
  }
}
