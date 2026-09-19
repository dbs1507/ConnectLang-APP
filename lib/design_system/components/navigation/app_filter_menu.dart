import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../theme/app_colors.dart';
import 'app_choice_chips.dart';

/// Filtro em um único controle — abre as opções num menu, em vez de
/// uma faixa de chips que compete com as abas.
class AppFilterMenu<T> extends StatelessWidget {
  const AppFilterMenu({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<AppChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  String get _title {
    for (final option in options) {
      if (option.value == selected) {
        if (option.value == null) return label;
        return option.label;
      }
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: label,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(
            value: option.value,
            child: Text(
              option.label,
              style: TextStyle(
                fontWeight: option.value == selected
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: AppColors.heading,
              ),
            ),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                _title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              LucideIcons.chevron_down,
              size: 18,
              color: AppColors.foreground,
            ),
          ],
        ),
      ),
    );
  }
}
