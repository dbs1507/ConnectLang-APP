import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/learner_routes.dart';
import '../../core/session/auth_controller.dart';
import '../../design_system/components/sheets/app_bottom_sheet.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
import 'notebook_entry_sheet.dart';

/// Atalho flutuante do Caderno — ao toque, escolhe entre nova nota ou
/// abrir a lista. Espelha o papel do `NotebookFab` no web.
class NotebookFab extends ConsumerWidget {
  const NotebookFab({super.key});

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final choice = await showAppBottomSheet<_NotebookFabChoice>(
      context: context,
      initialSize: 0.38,
      minSize: 0.32,
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Caderno', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            _FabTile(
              icon: LucideIcons.notebook_pen,
              label: 'Adicionar nota',
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_NotebookFabChoice.addNote),
            ),
            _FabTile(
              icon: LucideIcons.notebook,
              label: 'Abrir caderno',
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_NotebookFabChoice.openNotebook),
            ),
          ],
        );
      },
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case _NotebookFabChoice.addNote:
        showNotebookComposer(context);
      case _NotebookFabChoice.openNotebook:
        final role = ref.read(authControllerProvider).value?.role;
        context.push(LearnerPaths.notebook(role));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      heroTag: null,
      tooltip: 'Caderno',
      backgroundColor: AppColors.notebook,
      foregroundColor: Colors.white,
      onPressed: () => _openMenu(context, ref),
      child: const Icon(LucideIcons.square_pen),
    );
  }
}

class _FabTile extends StatelessWidget {
  const _FabTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.heading),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.heading,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        LucideIcons.chevron_right,
        size: 18,
        color: AppColors.navText,
      ),
      onTap: onTap,
    );
  }
}

enum _NotebookFabChoice { addNote, openNotebook }
