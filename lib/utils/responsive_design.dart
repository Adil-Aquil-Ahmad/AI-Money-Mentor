import 'package:flutter/material.dart';

/// Utility class for responsive design values
class ResponsiveDesign {
  static const double breakpointMobile = 600;
  static const double breakpointTablet = 900;
  static const double breakpointDesktop = 1200;

  /// Get responsive padding based on screen width
  static double getPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) return 16.0;
    if (width < breakpointTablet) return 24.0;
    if (width < breakpointDesktop) return 32.0;
    return 48.0;
  }

  /// Get responsive header font size
  static double getHeaderFontSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) return 28.0;
    if (width < breakpointTablet) return 32.0;
    if (width < breakpointDesktop) return 36.0;
    return 40.0;
  }

  /// Get responsive subheader font size
  static double getSubheaderFontSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) return 14.0;
    if (width < breakpointTablet) return 16.0;
    return 18.0;
  }

  /// Get responsive major spacing
  static double getSpacingMajor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) return 20.0;
    if (width < breakpointTablet) return 28.0;
    if (width < breakpointDesktop) return 36.0;
    return 48.0;
  }

  /// Get responsive medium spacing
  static double getSpacingMedium(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) return 14.0;
    if (width < breakpointTablet) return 18.0;
    if (width < breakpointDesktop) return 24.0;
    return 32.0;
  }

  /// Get responsive minor spacing
  static double getSpacingMinor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) return 8.0;
    if (width < breakpointTablet) return 12.0;
    if (width < breakpointDesktop) return 16.0;
    return 20.0;
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context, {double baseSize = 24}) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) return baseSize;
    if (width < breakpointTablet) return baseSize + 4;
    if (width < breakpointDesktop) return baseSize + 8;
    return baseSize + 12;
  }

  /// Get chart height based on screen size
  static double getChartHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    if (width < breakpointMobile) return height * 0.35;
    if (width < breakpointTablet) return height * 0.40;
    return height * 0.50;
  }

  /// Check if screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < breakpointMobile;
  }

  /// Check if screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= breakpointMobile && width < breakpointDesktop;
  }

  /// Check if screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= breakpointDesktop;
  }

  /// Get grid columns for adaptive layouts
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) return 2;
    if (width < breakpointTablet) return 3;
    if (width < breakpointDesktop) return 4;
    return 6;
  }
}
