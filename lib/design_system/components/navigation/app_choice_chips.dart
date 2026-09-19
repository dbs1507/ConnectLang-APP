import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppChoiceOption<T> {
  const AppChoiceOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Filtros horizontais retos — substitui FilterChip em pílula nas listas.
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding,
  });

  final List<AppChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            padding ??
            const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.value == selected;
          return Material(
            color: isSelected ? AppColors.heading : AppColors.background,
            child: InkWell(
              onTap: () => onSelected(option.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Center(
                  child: Text(
                    option.label,
                    style: textTheme.labelMedium?.copyWith(
                      color: isSelected ? Colors.white : AppColors.foreground,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
