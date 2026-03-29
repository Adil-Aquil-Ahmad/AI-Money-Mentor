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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              _formatValue(value),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: AppColors.primaryGradient,
          ).createShader(bounds),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions.toInt(),
            onChanged: onChanged,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.whiteOpacity(0.1),
          ),
        ),
      ],
    );
  }
}
