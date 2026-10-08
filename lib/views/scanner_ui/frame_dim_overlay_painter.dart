import 'package:flutter/material.dart';
import 'package:mangroveguardapp/theme/colors.dart';

class FrameDimOverlayPainter extends CustomPainter {
  const FrameDimOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const frameWidth = 260.0;
    const frameHeight = 420.0;
    const frameAlignment = Alignment(0, -0.50);

    final frameLeft =
        (size.width - frameWidth) / 2 +
        frameAlignment.x * (size.width - frameWidth) / 2;
    final frameTop =
        (size.height - frameHeight) / 2 +
        frameAlignment.y * (size.height - frameHeight) / 2;
    final frameRect = Rect.fromLTWH(
      frameLeft,
      frameTop,
      frameWidth,
      frameHeight,
    );

    final paint = Paint()
      ..color = AppColors.richBlack.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    path.addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(8)));
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
