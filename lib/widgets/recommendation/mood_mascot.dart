import 'package:flutter/material.dart';

/// Rice-shaped expressions share the app mascot's dot eyes and brown linework.
class MoodMascot extends StatelessWidget {
  final String mood;
  const MoodMascot({super.key, required this.mood});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(64, 68), painter: _MoodPainter(mood));
}

class _MoodPainter extends CustomPainter {
  final String mood;
  _MoodPainter(this.mood);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 68);
    final ink = Paint()
      ..color = const Color(0xFF4C281B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final rice = Path()
      ..moveTo(47, 5)
      ..cubicTo(37, -2, 10, 21, 6, 44)
      ..cubicTo(0, 67, 53, 69, 58, 48)
      ..cubicTo(60, 35, 55, 10, 47, 5)
      ..close();
    canvas.drawPath(rice, Paint()..color = Colors.white);
    canvas.drawPath(
      rice,
      Paint()
        ..color = const Color(0xFFD4D0D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final happy = mood == '기분 좋음';
    final tired = mood == '피곤함';
    final stressed = mood == '스트레스';
    final sad = mood == '우울함';
    for (final x in [22.0, 44.0]) {
      if (happy) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 4, 38)
            ..lineTo(x, 33)
            ..lineTo(x + 4, 38),
          ink,
        );
      } else if (tired) {
        canvas.drawLine(Offset(x - 4, 37), Offset(x + 4, 37), ink);
      } else {
        canvas.drawCircle(Offset(x, 38), 3.3, Paint()..color = ink.color);
      }
    }
    if (stressed || sad) {
      canvas.drawLine(
        Offset(18, stressed ? 29 : 27),
        Offset(25, stressed ? 33 : 23),
        ink,
      );
      canvas.drawLine(
        Offset(40, stressed ? 33 : 23),
        Offset(47, stressed ? 29 : 27),
        ink,
      );
      canvas.drawPath(
        Path()
          ..moveTo(27, 51)
          ..quadraticBezierTo(33, 44, 39, 51),
        ink,
      );
    } else if (tired) {
      canvas.drawOval(const Rect.fromLTWH(30, 47, 6, 8), ink);
    } else if (happy) {
      canvas.drawPath(
        Path()
          ..moveTo(25, 47)
          ..quadraticBezierTo(33, 59, 41, 47)
          ..close(),
        ink,
      );
    } else {
      canvas.drawLine(const Offset(28, 48), const Offset(39, 48), ink);
    }
    if (sad) {
      canvas.drawPath(
        Path()
          ..moveTo(52, 43)
          ..quadraticBezierTo(41, 59, 52, 59)
          ..quadraticBezierTo(61, 57, 52, 43),
        Paint()..color = const Color(0xFF28AEEC),
      );
    }
    if (stressed) {
      final anger = Paint()
        ..color = const Color(0xFFFD5D69)
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(50, 4)
          ..lineTo(50, 9)
          ..lineTo(45, 9)
          ..moveTo(55, 4)
          ..lineTo(55, 9)
          ..lineTo(60, 9)
          ..moveTo(45, 14)
          ..lineTo(50, 14)
          ..lineTo(50, 19)
          ..moveTo(55, 19)
          ..lineTo(55, 14)
          ..lineTo(60, 14),
        anger,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MoodPainter oldDelegate) => oldDelegate.mood != mood;
}
