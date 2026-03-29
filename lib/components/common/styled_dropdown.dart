import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'glass_card.dart';

/// Reusable dropdown widget with glass-morphism design
class StyledDropdown<T> extends StatefulWidget {
  final String label;
  final String hint;
  final T? initialValue;
  final List<String> items;
  final Function(String) onChanged;
  final bool isEnabled;
  final IconData? prefixIcon;
  final double? width;

  const StyledDropdown({
    Key? key,
    required this.label,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.isEnabled = true,
    this.prefixIcon,
    this.width,
  }) : super(key: key);

  @override
  State<StyledDropdown<T>> createState() => _StyledDropdownState<T>();
}

class _StyledDropdownState<T> extends State<StyledDropdown<T>> {
  late String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        // Dropdown
        GlassCard(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: DropdownButtonFormField<String>(
            value: _selectedValue,
            items: widget.items.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: widget.isEnabled
                ? (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedValue = newValue;
                      });
                      widget.onChanged(newValue);
                    }
                  }
                : null,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: AppColors.textTertiary.withOpacity(0.7),
              ),
              border: InputBorder.none,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: AppColors.primary,
                      size: 18,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              filled: false,
              enabled: widget.isEnabled,
              isDense: true,
            ),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isMobile ? 12 : 14,
            ),
            dropdownColor: const Color(0xFF153C6A),
            iconEnabledColor: AppColors.primary,
            iconDisabledColor: AppColors.textTertiary,
            disabledHint: Text(
              widget.hint,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: AppColors.textTertiary.withOpacity(0.5),
              ),
            ),
            isExpanded: true,
          ),
        ),
      ],
    );
  }
}

/// Multi-select dropdown widget for multiple selections
class MultiSelectDropdown extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> items;
  final List<String> selectedItems;
  final Function(List<String>) onChanged;
  final bool isEnabled;
  final int maxSelections;

  const MultiSelectDropdown({
    Key? key,
    required this.label,
    required this.hint,
    required this.items,
    required this.selectedItems,
    required this.onChanged,
    this.isEnabled = true,
    this.maxSelections = 3,
  }) : super(key: key);

  @override
  State<MultiSelectDropdown> createState() => _MultiSelectDropdownState();
}

class _MultiSelectDropdownState extends State<MultiSelectDropdown> {
  late List<String> _selectedItems;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.selectedItems);
  }

  void _toggleItem(String item) {
    if (!widget.isEnabled) return;

    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        if (_selectedItems.length < widget.maxSelections) {
          _selectedItems.add(item);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Maximum ${widget.maxSelections} selections allowed',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
      }
    });
    widget.onChanged(_selectedItems);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        // Selected Items Display
        if (_selectedItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedItems.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.isEnabled) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _toggleItem(item),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        // Dropdown
        GlassCard(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: widget.items.map((item) {
              final isSelected = _selectedItems.contains(item);
              return GestureDetector(
                onTap: () => _toggleItem(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.2)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 12,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
                
              }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Numeric input with validation and formatting
class NumericInputField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final Function(double) onChanged;
  final bool isEnabled;
  final String? currency;
  final double? minValue;
  final double? maxValue;

  const NumericInputField({
    Key? key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.isEnabled = true,
    this.currency,
    this.minValue = 0.0,
    this.maxValue = double.infinity,
  }) : super(key: key);

  @override
  State<NumericInputField> createState() => _NumericInputFieldState();
}

class _NumericInputFieldState extends State<NumericInputField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _validateAndUpdate(String value) {
    double? parsed = double.tryParse(value);

    if (parsed != null) {
      if (parsed < (widget.minValue ?? 0.0)) {
        parsed = widget.minValue ?? 0.0;
      }
      if (parsed > (widget.maxValue ?? double.infinity)) {
        parsed = widget.maxValue ?? double.infinity;
      }
      widget.controller.text = parsed.toStringAsFixed(2);
      widget.onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        GlassCard(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            enabled: widget.isEnabled,
            onChanged: _validateAndUpdate,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: AppColors.textTertiary.withOpacity(0.7),
              ),
              border: InputBorder.none,
              prefixText: widget.currency != null ? '${widget.currency} ' : null,
              prefixStyle: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              suffixIcon: _focusNode.hasFocus
                  ? GestureDetector(
                      onTap: () {
                        widget.controller.clear();
                        widget.onChanged(0);
                      },
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              isDense: true,
            ),
          ),
        ),
        if (widget.minValue != null || widget.maxValue != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Range: ${widget.minValue?.toStringAsFixed(2) ?? 'N/A'} - ${widget.maxValue?.toStringAsFixed(2) ?? 'N/A'}',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}
