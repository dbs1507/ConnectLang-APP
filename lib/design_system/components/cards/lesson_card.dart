import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Card "continuar de onde parou" — a ação primária da home. Um título,
/// uma explicação curta de por quê (a razão dada pela LIA), um botão de
/// continuar e, opcionalmente, um atalho pra abrir o motivo completo da
/// LIA num bottom sheet (referência Headspace: uma tela de conteúdo, uma
/// ação primária óbvia, nada compete com ela).
class ContinueLessonCard extends StatelessWidget {
  const ContinueLessonCard({
    super.key,
    required this.title,
    required this.reason,
    required this.buttonLabel,
    required this.onContinue,
    this.onExplain,
  });

  final String title;
  final String reason;
  final String buttonLabel;
  final VoidCallback onContinue;
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(reason, style: textTheme.bodyMedium),
                ),
                if (onExplain != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: onExplain,
                    child: Text(
                      'LIA explica',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
