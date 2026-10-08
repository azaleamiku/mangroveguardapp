import 'package:flutter/material.dart';

class QrDimOverlayPainter extends CustomPainter {
  const QrDimOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final path = Path();
    final cutoutSize = 250.0;
    final frameTop = (size.height - cutoutSize) / 2 - 40;
    final frameLeft = (size.width - cutoutSize) / 2;
    final cutoutRect = Rect.fromLTWH(
      frameLeft,
      frameTop,
      cutoutSize,
      cutoutSize,
    );

    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    path.addRRect(
      RRect.fromRectAndRadius(cutoutRect, const Radius.circular(8)),
    );
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
