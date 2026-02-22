import 'package:flutter/material.dart';

class CustomFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? textColor;

  const CustomFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.backgroundColor,
    this.selectedColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (selectedColor ?? theme.colorScheme.primary.withOpacity(0.2))
              : (backgroundColor ?? theme.colorScheme.surface.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerTheme.color ?? Colors.grey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: textTheme.labelSmall?.fontSize,
              color: isSelected
                  ? theme.colorScheme.primary
                  : (textColor ?? theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (textColor ?? theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}