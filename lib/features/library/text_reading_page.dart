import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vocabulary/models/vocabulary_entry.dart';
import 'library_controller.dart';
import 'models/library_text.dart';

class TextReadingPage extends ConsumerWidget {
  const TextReadingPage({super.key, required this.text});

  final LibraryText text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = ref.watch(libraryControllerProvider).value?.isRead(text.id) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(text.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(isRead ? Icons.check_circle : Icons.check_circle_outline),
            tooltip: isRead ? 'Marcar como não lido' : 'Marcar como lido',
            onPressed: () => ref.read(libraryControllerProvider.notifier).toggleRead(text.id),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(taughtLanguages[text.language] ?? text.language)),
                  if (text.cefr != null) Chip(label: Text(text.cefr!)),
                ],
              ),
              const SizedBox(height: 16),
              MarkdownBody(data: text.content),
            ],
          ),
        ),
      ),
    );
  }
}
