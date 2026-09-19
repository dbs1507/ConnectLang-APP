import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppTextTab<T> {
  const AppTextTab({required this.value, required this.label});

  final T value;
  final String label;
}

/// Abas de página no estilo app: texto compacto à esquerda, ativo em
/// negrito, traço curto por baixo. Não estica como menu de site.
class AppTextTabs<T> extends StatelessWidget {
  const AppTextTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.padding,
    this.compact = false,
  });

  final List<AppTextTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry? padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            AppSpacing.xl,
            compact ? 0 : AppSpacing.xs,
            AppSpacing.xl,
            compact ? 0 : AppSpacing.md,
          ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) SizedBox(width: compact ? 18 : 20),
              _Tab(
                label: tabs[i].label,
                selected: tabs[i].value == selected,
                compact: compact,
                onTap: () => onSelected(tabs[i].value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = (compact ? textTheme.titleSmall : textTheme.titleMedium)
        ?.copyWith(
          color: selected ? AppColors.heading : AppColors.foreground,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );

    return InkWell(
      onTap: onTap,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(label, style: style),
            ),
            Container(
              height: 3,
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
