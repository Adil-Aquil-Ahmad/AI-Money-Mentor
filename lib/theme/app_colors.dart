import 'package:flutter/material.dart';

class AppColors {
  // ─── Dark Theme Colors (Default) ──────────────────────────────────────────
  static const Color primary = Color(0xFF3DE0FC); // Cyan
  static const Color primaryDark = Color(0xFF2475AC);
  static const Color secondary = Color(0xFFE977F5); // Purple
  static const Color secondaryDark = Color(0xFF733E85);
  
  static const Color background = Color(0xFF042142); // Very dark blue
  static const Color surfaceColor = Color(0xFF042142);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1); // slate-300
  static const Color textTertiary = Color(0xFF94A3B8); // slate-400
  
  // ─── Golden Light Theme Colors (Wealth / Premium style) ───────────────────
  static const Color lightPrimary = Color(0xFFC5960C); // Rich Metallic Gold
  static const Color lightPrimaryDark = Color(0xFF8B6914); // Dark Bronze
  static const Color lightSecondary = Color(0xFF1B7A3D); // Money Emerald Green
  static const Color lightSecondaryDark = Color(0xFF145A2D); // Deep Forest Green
  static const Color lightAccentGreen = Color(0xFF22A24E); // Bright money green
  static const Color lightAccentGold = Color(0xFFDAA520); // Classic goldenrod
  
  static const Color lightBackground = Color(0xFFFAF8F3); // Warm Ivory
  static const Color lightSurfaceColor = Color(0xFFFFFFFF);
  
  // High contrast text against FAF8F3 (WCAG > 5.9)
  static const Color lightTextPrimary = Color(0xFF1A1610); // Near-black brown
  static const Color lightTextSecondary = Color(0xFF4A3F2A); // Bronze/brown
  static const Color lightTextTertiary = Color(0xFF6B5D3E); // Warm mocha
  
  // ─── Status Colors ────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFF87171);
  static const Color warning = Color(0xFFFB923C);
  static const Color info = Color(0xFF3B82F6);
  
  // ─── Brand Color Helpers ──────────────────────────────────────────────────
  static Color getBrandPrimary(bool isDark) => isDark ? primary : lightPrimary;
  static Color getBrandSecondary(bool isDark) => isDark ? secondary : lightSecondary;
  
  static List<Color> getBrandGradient(bool isDark) => isDark 
      ? [const Color(0xFF3DE0FC), const Color(0xFF2475AC)] 
      : [const Color(0xFFC5960C), const Color(0xFF8B6914)];
  
  static List<Color> getSecondaryGradient(bool isDark) => isDark
      ? [const Color(0xFFE977F5), const Color(0xFF733E85)]
      : [const Color(0xFF22A24E), const Color(0xFF145A2D)];
  
  // ─── Background Helpers ───────────────────────────────────────────────────
  static Color getBackground(bool isDark) => isDark ? background : lightBackground;
  
  // ─── Text Helpers ─────────────────────────────────────────────────────────
  static Color getTextPrimary(bool isDark) => isDark ? textPrimary : lightTextPrimary;
  static Color getTextSecondary(bool isDark) => isDark ? textSecondary : lightTextSecondary;
  static Color getTextTertiary(bool isDark) => isDark ? textTertiary : lightTextTertiary;
  
  // ─── Glass / Surface Helpers ──────────────────────────────────────────────
  static Color getIcon(bool isDark) => isDark ? textPrimary : lightTextPrimary;

  static Color getBorder(bool isDark, [double opacity = 0.1]) {
    return isDark 
        ? Colors.white.withOpacity(opacity) 
        : const Color(0xFFC5960C).withOpacity(opacity * 1.8);
  }

  static Color getGlassBg(bool isDark, [double opacity = 0.02]) {
    return isDark 
        ? Colors.white.withOpacity(opacity) 
        : const Color(0xFFFFFFFF).withOpacity(0.70);
  }

  /// Card background that is more visible in light mode
  static Color getCardBg(bool isDark) {
    return isDark
        ? Colors.white.withOpacity(0.03)
        : const Color(0xFFFFFDF7).withOpacity(0.92);
  }

  /// Dropdown menu background
  static Color getDropdownBg(bool isDark) {
    return isDark
        ? const Color(0xFF153C6A)
        : const Color(0xFFFFFDF7);
  }

  /// Dialog / modal background
  static Color getDialogBg(bool isDark) {
    return isDark
        ? const Color(0xFF0d2d52)
        : const Color(0xFFFFFDF7);
  }

  /// Sheet / bottom-sheet background
  static Color getSheetBg(bool isDark) {
    return isDark
        ? const Color(0xFF0a1f3a)
        : const Color(0xFFFAF8F3);
  }

  // ─── Static Gradient Lists (dark-only, kept for backward compat) ──────────
  static const List<Color> primaryGradient = [
    Color(0xFF3DE0FC),
    Color(0xFF2475AC),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFFE977F5),
    Color(0xFF733E85),
  ];

  // ─── Opacity Helpers ──────────────────────────────────────────────────────
  static Color whiteOpacity(double opacity) {
    return Colors.white.withOpacity(opacity);
  }

  /// Theme-aware subtle overlay: white in dark, warm brown in light
  static Color getOverlay(bool isDark, double opacity) {
    return isDark
        ? Colors.white.withOpacity(opacity)
        : const Color(0xFF8B6914).withOpacity(opacity * 0.6);
  }
}
