import 'package:flutter/material.dart';

import '../styles.dart';

class _TargetIconPainter extends CustomPainter {
  const _TargetIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = darkElementColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        2,
        Paint()
          ..color = darkElementColor
          ..style = PaintingStyle.fill);
    final Path path = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: 12,
      ))
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: 6.5,
      ))
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TargetIconPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(_TargetIconPainter oldDelegate) => false;
}

class TargetIcon extends StatelessWidget {
  const TargetIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _TargetIconPainter(),
      size: Size.square(24),
      willChange: false,
      isComplex: false,
    );
  }
}
