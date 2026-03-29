import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/app_colors.dart';

/// Full-screen background matching the HTML design:
/// - Deep navy `#042142` base for Dark Mode
/// - Warm ivory `#FAF8F3` base for Light Mode with gold/green orbs
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: AppColors.getBackground(isDark),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Orb 1: top-left ───────────────────────────────
          Positioned(
            top: -150,
            left: -150,
            child: _Orb(
              size: 520,
              color: isDark
                  ? const Color(0xFF733E85).withOpacity(0.38)
                  : const Color(0xFFC5960C).withOpacity(0.08),
              blur: 130,
            ),
          ),
          // ── Orb 2: top-right ──────────────────────────────
          Positioned(
            top: 80,
            right: -60,
            child: _Orb(
              size: 420,
              color: isDark
                  ? const Color(0xFF153C6A).withOpacity(0.50)
                  : const Color(0xFF1B7A3D).withOpacity(0.06),
              blur: 130,
            ),
          ),
          // ── Orb 3: bottom-left ─────────────────────────────
          Positioned(
            bottom: -80,
            left: 180,
            child: _Orb(
              size: 580,
              color: isDark
                  ? const Color(0xFF3DE0FC).withOpacity(0.15)
                  : const Color(0xFFDAA520).withOpacity(0.10),
              blur: 150,
            ),
          ),
          // ── Orb 4: bottom-right ────────────────────────────
          Positioned(
            bottom: 20,
            right: -80,
            child: _Orb(
              size: 460,
              color: isDark
                  ? const Color(0xFFE977F5).withOpacity(0.25)
                  : const Color(0xFF22A24E).withOpacity(0.07),
              blur: 140,
            ),
          ),
          // ── Content ───────────────────────────────────────────────────
          child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double blur;

  const _Orb({
    required this.size,
    required this.color,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
