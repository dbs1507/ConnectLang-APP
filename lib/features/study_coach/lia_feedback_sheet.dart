import 'package:flutter/material.dart';

import '../../design_system/components/feedback/lia_sheet_header.dart';
import '../../design_system/components/sheets/app_bottom_sheet.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import '../../design_system/theme/app_typography.dart';
import 'models/study_coach_plan.dart';

/// Bottom sheet de feedback da LIA — por que ela sugeriu a ação atual.
/// Decisão de referência: Babbel/Headspace mostram o "porquê" fora do
/// fluxo principal de prática, num painel que não bloqueia; aqui isso é
/// literalmente um bottom sheet (decisão de 1 toque: ler e fechar), nunca
/// uma tela cheia — full-screen é só pra fluxos com etapas.
Future<void> showLiaFeedbackSheet(
  BuildContext context, {
  required StudyCoachPlan plan,
  StudyCoachAction? action,
}) {
  return showAppBottomSheet(
    context: context,
    initialSize: 0.55,
    builder: (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiaSheetHeader(
            title: action?.title ?? plan.summary,
            subtitle: action == null ? null : plan.summary,
          ),
          if (action != null && action.reason.isNotEmpty) ...[
            Text(action.reason, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (plan.focusAreas.isNotEmpty) ...[
            Text('Foco de hoje', style: AppTypography.microLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final focus in plan.focusAreas)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: const BoxDecoration(
                      border: Border.fromBorderSide(
                        BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Text(
                      focus,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (plan.evidence.isNotEmpty) ...[
            Text('Baseado em', style: AppTypography.microLabel),
            const SizedBox(height: AppSpacing.sm),
            for (final item in plan.evidence)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  '· ${item.text}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ],
      );
    },
  );
}
