import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Cabeçalho mínimo de identidade da LIA — uma marca pequena e texto,
/// sem avatar ilustrado ou animação. A LIA é uma ferramenta de estudo,
/// não um personagem; o peso visual fica no conteúdo do sheet, não nela.
class LiaSheetHeader extends StatelessWidget {
  const LiaSheetHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'LIA',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!, style: textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
