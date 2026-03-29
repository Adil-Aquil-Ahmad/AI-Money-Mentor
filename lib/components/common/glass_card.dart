import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool isHoverable;
  final Duration animationDuration;
  final Color? backgroundColor;
  final double blurAmount;
  final Color? glowColor;

  const GlassCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 32,
    this.onTap,
    this.isHoverable = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.backgroundColor,
    this.blurAmount = 20,
    this.glowColor,
  }) : super(key: key);

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.01).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    if (widget.isHoverable) {
      _hoverController.forward();
    }
  }

  void _onHoverExit() {
    if (widget.isHoverable) {
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Base colors that adapt to theme
    final borderColor = AppColors.getBorder(isDark);
    final bgGradientColor = widget.backgroundColor ?? AppColors.getGlassBg(isDark);

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: isDark 
                          ? Colors.black.withOpacity(0.2) 
                          : const Color(0xFFC5960C).withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: widget.blurAmount,
                      sigmaY: widget.blurAmount,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        border: Border.all(color: borderColor, width: 1),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            bgGradientColor,
                            bgGradientColor.withOpacity(
                                bgGradientColor.opacity * (isDark ? 0.7 : 0.9)),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Optional internal masked glow
                          if (widget.glowColor != null && isDark)
                            Positioned(
                              top: -40,
                              left: -40,
                              child: IgnorePointer(
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.glowColor!.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Content
                          Padding(
                            padding: widget.padding,
                            child: widget.child,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
