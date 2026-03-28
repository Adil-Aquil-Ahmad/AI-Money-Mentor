import 'package:flutter/material.dart';

class AppColors {
  // Dark Theme Colors (Default)
  static const Color primary = Color(0xFF3DE0FC); // Cyan
  static const Color primaryDark = Color(0xFF2475AC);
  static const Color secondary = Color(0xFFE977F5); // Purple
  static const Color secondaryDark = Color(0xFF733E85);
  
  static const Color background = Color(0xFF042142); // Very dark blue
  static const Color surfaceColor = Color(0xFF042142);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1); // slate-300
  static const Color textTertiary = Color(0xFF94A3B8); // slate-400
  
  // ─── Golden Light Theme Colors (Wealth / Premium style) ───────
  static const Color lightPrimary = Color(0xFFD4AF37); // Metallic Gold
  static const Color lightPrimaryDark = Color(0xFFB8860B); // Dark Goldenrod
  static const Color lightSecondary = Color(0xFF8B6508); // Deep Bronze
  static const Color lightBackground = Color(0xFFF9F7F1); // Elegant Cream/Ivory
  static const Color lightSurfaceColor = Color(0xFFFFFFFF);
  
  // High contrast text against F9F7F1 (WCAG > 5.9)
  static const Color lightTextPrimary = Color(0xFF1E1A11); // Deepest brown/charcoal
  static const Color lightTextSecondary = Color(0xFF4A412A); // Bronze/brown
  static const Color lightTextTertiary = Color(0xFF73674B); // Mocha
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFF87171);
  static const Color warning = Color(0xFFFB923C);
  static const Color info = Color(0xFF3B82F6);
  
  // Method helpers for brand colors
  static Color getBrandPrimary(bool isDark) => isDark ? primary : lightPrimaryDark;
  static Color getBrandSecondary(bool isDark) => isDark ? secondary : lightSecondary;
  static List<Color> getBrandGradient(bool isDark) => isDark 
      ? [const Color(0xFF3DE0FC), const Color(0xFF2475AC)] 
      : [const Color(0xFFD4AF37), const Color(0xFFB8860B)];
  
  // Background helpers
  static Color getBackground(bool isDark) => isDark ? background : lightBackground;
  
  // Text helpers
  static Color getTextPrimary(bool isDark) => isDark ? textPrimary : lightTextPrimary;
  static Color getTextSecondary(bool isDark) => isDark ? textSecondary : lightTextSecondary;
  static Color getTextTertiary(bool isDark) => isDark ? textTertiary : lightTextTertiary;
  
  // Glass Helpers
  static Color getIcon(bool isDark) => isDark ? textPrimary : lightTextPrimary;

  static Color getBorder(bool isDark, [double opacity = 0.1]) {
    // In light mode, golden-bronze borders look premium and glass-like
    return isDark 
        ? Colors.white.withOpacity(opacity) 
        : const Color(0xFFB8860B).withOpacity(opacity * 1.5);
  }

  static Color getGlassBg(bool isDark, [double opacity = 0.02]) {
    // In light mode, a slightly warm white backdrop blur
    return isDark 
        ? Colors.white.withOpacity(opacity) 
        : const Color(0xFFFFFFFF).withOpacity(0.65);
  }

  // Gradient helpers
  static const List<Color> primaryGradient = [
    Color(0xFF3DE0FC),
    Color(0xFF2475AC),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFFE977F5),
    Color(0xFF733E85),
  ];

  // White opacity helper
  static Color whiteOpacity(double opacity) {
    return Colors.white.withOpacity(opacity);
  }
}
