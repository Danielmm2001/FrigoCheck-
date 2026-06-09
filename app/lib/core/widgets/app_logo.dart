import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 48,
    this.centered = false,
  });

  final double height;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final iconSize = height;
    final textSize = height * 0.62;

    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        _LogoMark(size: iconSize),
        SizedBox(width: height * 0.26),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
            children: const [
              TextSpan(
                  text: 'Frigo', style: TextStyle(color: AppColors.primary)),
              TextSpan(
                  text: 'Check',
                  style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.78,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF22C99A), AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: size * 0.24,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: CustomPaint(painter: _LogoMarkPainter()),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final thin = white..strokeWidth = size.width * 0.06;

    canvas.drawLine(
      Offset(size.width * 0.26, size.height * 0.19),
      Offset(size.width * 0.26, size.height * 0.35),
      thin,
    );
    canvas.drawLine(
      Offset(size.width * 0.26, size.height * 0.47),
      Offset(size.width * 0.26, size.height * 0.60),
      thin,
    );

    canvas.drawLine(
      Offset(size.width * 0.02, size.height * 0.40),
      Offset(size.width * 0.98, size.height * 0.40),
      thin,
    );

    final check = Path()
      ..moveTo(size.width * 0.32, size.height * 0.64)
      ..lineTo(size.width * 0.48, size.height * 0.76)
      ..lineTo(size.width * 0.78, size.height * 0.55);

    canvas.drawPath(check, thin..strokeWidth = size.width * 0.085);

    final footPaint = Paint()..color = Colors.white.withValues(alpha: 0.96);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.18, size.height * 0.92, size.width * 0.14,
            size.height * 0.06),
        Radius.circular(size.width * 0.03),
      ),
      footPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.68, size.height * 0.92, size.width * 0.14,
            size.height * 0.06),
        Radius.circular(size.width * 0.03),
      ),
      footPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
