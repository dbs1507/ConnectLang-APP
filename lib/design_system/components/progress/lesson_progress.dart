import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Progresso neutro — "Passo 3 de 5" + trilha discreta de segmentos.
/// Sem streak, XP ou crown: só onde o aluno está e quanto falta
/// (visibilidade do status do sistema, sem gamificação).
class LessonProgress extends StatelessWidget {
  const LessonProgress({
    super.key,
    required this.current,
    required this.total,
    this.label,
  }) : assert(total > 0, 'total precisa ser maior que zero'),
       assert(current >= 0 && current <= total);

  final int current;
  final int total;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label ?? 'Passo $current de $total',
          style: AppTypography.microLabel,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  color: i < current ? AppColors.primary : AppColors.border,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
