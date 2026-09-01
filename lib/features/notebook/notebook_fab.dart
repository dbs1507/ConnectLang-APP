import 'package:flutter/material.dart';

import 'notebook_entry_sheet.dart';

/// Atalho flutuante do Caderno — mesmo papel do `NotebookFab` no web
/// (`src/components/notebook/NotebookFab.tsx`): abre o compositor em qualquer
/// tela do aluno/assinante.
class NotebookFab extends StatelessWidget {
  const NotebookFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'notebook-fab',
      tooltip: 'Nova nota no caderno',
      onPressed: () => showNotebookComposer(context),
      child: const Icon(Icons.menu_book_outlined),
    );
  }
}
