import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vocabulary/models/vocabulary_entry.dart';
import 'library_controller.dart';
import 'text_reading_page.dart';

class LibraryListPage extends ConsumerWidget {
  const LibraryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(libraryControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Não foi possível carregar a biblioteca.\n$error', textAlign: TextAlign.center),
          ),
        ),
        data: (libraryState) {
          final texts = libraryState.texts;
          if (texts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Ainda não há textos na biblioteca.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: texts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final text = texts[index];
              final isRead = libraryState.isRead(text.id);
              return ListTile(
                title: Text(text.title),
                subtitle: Text(
                  [
                    taughtLanguages[text.language] ?? text.language,
                    if (text.cefr != null) text.cefr!,
                  ].join(' · '),
                ),
                trailing: IconButton(
                  icon: Icon(isRead ? Icons.check_circle : Icons.check_circle_outline),
                  tooltip: isRead ? 'Marcar como não lido' : 'Marcar como lido',
                  onPressed: () => ref.read(libraryControllerProvider.notifier).toggleRead(text.id),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TextReadingPage(text: text)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
