import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/app_colors.dart';

/// Full-screen background matching the HTML design:
/// - Deep navy `#042142` base for Dark Mode
/// - Light slate `#F8FAFC` base for Light Mode
/// - 4 gaussian orbs at corners 
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
          // ── Orb 1: top-left purple ───────────────────────────
          Positioned(
            top: -150,
            left: -150,
            child: _Orb(
              size: 520,
              color: const Color(0xFF733E85).withOpacity(isDark ? 0.38 : 0.05),
              blur: 130,
            ),
          ),
          // ── Orb 2: top-right dark-navy ──────────────────────
          Positioned(
            top: 80,
            right: -60,
            child: _Orb(
              size: 420,
              color: const Color(0xFF153C6A).withOpacity(isDark ? 0.50 : 0.04),
              blur: 130,
            ),
          ),
          // ── Orb 3: bottom-left cyan ─────────────────────────
          Positioned(
            bottom: -80,
            left: 180,
            child: _Orb(
              size: 580,
              color: const Color(0xFF3DE0FC).withOpacity(isDark ? 0.15 : 0.08),
              blur: 150,
            ),
          ),
          // ── Orb 4: bottom-right pink ────────────────────────
          Positioned(
            bottom: 20,
            right: -80,
            child: _Orb(
              size: 460,
              color: const Color(0xFFE977F5).withOpacity(isDark ? 0.25 : 0.06),
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
