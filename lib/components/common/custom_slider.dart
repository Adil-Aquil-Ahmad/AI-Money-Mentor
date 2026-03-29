import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CustomSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double divisions;
  final String suffix;
  final Function(double) onChanged;

  const CustomSlider({
    Key? key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions = 100,
    this.suffix = '',
    required this.onChanged,
  }) : super(key: key);

  String _formatValue(double val) {
    if (suffix.isEmpty) return val.toStringAsFixed(0);
    if (suffix == '%') return '${val.toStringAsFixed(1)}%';
    if (suffix == '₹') {
      if (val >= 100000) {
        return '₹${(val / 100000).toStringAsFixed(1)}L';
      }
      return '₹${val.toStringAsFixed(0)}';
    }
    return '${val.toStringAsFixed(0)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    final brandGradient = AppColors.getBrandGradient(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextTertiary(isDark),
              ),
            ),
            Text(
              _formatValue(value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: brandPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: brandGradient,
          ).createShader(bounds),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions.toInt(),
            onChanged: onChanged,
            activeColor: brandPrimary,
            inactiveColor: AppColors.getOverlay(isDark, 0.1),
          ),
        ),
      ],
    );
  }
}
