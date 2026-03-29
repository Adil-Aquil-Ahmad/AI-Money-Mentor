import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CustomInputField extends StatefulWidget {
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool obscureText;

  const CustomInputField({
    Key? key,
    required this.label,
    this.hint = '',
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.controller,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.obscureText = false,
  }) : super(key: key);

  @override
  State<CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<CustomInputField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  IconTheme(
                    data: const IconThemeData(
                      color: AppColors.primary,
                      size: 18,
                    ),
                    child: widget.prefixIcon!,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextSecondary(isDark),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isFocused
                  ? AppColors.getBrandPrimary(isDark).withOpacity(0.6)
                  : AppColors.getBorder(isDark, 0.15),
              width: 1.5,
            ),
            color: _isFocused
                ? AppColors.getBrandPrimary(isDark).withOpacity(0.05)
                : AppColors.getGlassBg(isDark, 0.02),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.getBrandPrimary(isDark).withOpacity(0.15),
                      blurRadius: 15,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            obscureText: widget.obscureText,
            onChanged: widget.onChanged,
            style: TextStyle(
              color: AppColors.getTextPrimary(isDark),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: AppColors.getTextTertiary(isDark),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 12,
                      ),
                      child: widget.prefixIcon,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
