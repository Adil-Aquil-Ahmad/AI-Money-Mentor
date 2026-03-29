import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum ButtonType { primary, secondary, outlined, text }

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final ButtonType type;
  final double width;
  final double height;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool isLoading;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.width = double.infinity,
    this.height = 56,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: MouseRegion(
        onEnter: (_) => _hoverController.forward(),
        onExit: (_) => _hoverController.reverse(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(widget.height / 2),
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    decoration: _buildDecoration(isDark),
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.leadingIcon != null) ...[
                                  widget.leadingIcon!,
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  widget.text,
                                  style: _buildTextStyle(isDark),
                                ),
                                if (widget.trailingIcon != null) ...[
                                  const SizedBox(width: 8),
                                  widget.trailingIcon!,
                                ],
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(bool isDark) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    final brandGradient = AppColors.getBrandGradient(isDark);
    final secondaryGradient = AppColors.getSecondaryGradient(isDark);

    switch (widget.type) {
      case ButtonType.primary:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.height / 2),
          gradient: LinearGradient(
            colors: brandGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: brandPrimary.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case ButtonType.secondary:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.height / 2),
          gradient: LinearGradient(
            colors: secondaryGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.getBrandSecondary(isDark).withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case ButtonType.outlined:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.height / 2),
          border: Border.all(
            color: brandPrimary.withOpacity(0.5),
            width: 2,
          ),
          color: brandPrimary.withOpacity(0.1),
          boxShadow: [
            BoxShadow(
              color: brandPrimary.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case ButtonType.text:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.height / 2),
          color: Colors.transparent,
        );
    }
  }

  TextStyle _buildTextStyle(bool isDark) {
    final brandPrimary = AppColors.getBrandPrimary(isDark);
    
    switch (widget.type) {
      case ButtonType.primary:
      case ButtonType.secondary:
        return const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        );
      case ButtonType.outlined:
      case ButtonType.text:
        return TextStyle(
          color: brandPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        );
    }
  }
}
