import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
import 'models/notebook_entry.dart';
import 'notebook_repository.dart';

final notebookRepositoryProvider = Provider<NotebookRepository>((ref) {
  final userId = ref.watch(authControllerProvider).value?.id;
  if (userId == null) {
    throw StateError('notebookRepositoryProvider lido sem usuário autenticado.');
  }
  return NotebookRepository(userId);
});

final notebookControllerProvider =
    AsyncNotifierProvider<NotebookController, List<NotebookEntry>>(NotebookController.new);

class NotebookController extends AsyncNotifier<List<NotebookEntry>> {
  @override
  Future<List<NotebookEntry>> build() {
    return ref.read(notebookRepositoryProvider).fetchAll();
  }

  Future<void> addEntry({
    required String content,
    required String language,
    NotebookLinkType? linkType,
    String? linkId,
    String? linkLabel,
  }) async {
    final repo = ref.read(notebookRepositoryProvider);
    final entry = await repo.create(
      content: content,
      language: language,
      linkType: linkType,
      linkId: linkId,
      linkLabel: linkLabel,
    );
    state = AsyncData([entry, ...state.value ?? []]);
  }

  Future<void> updateEntry({
    required String entryId,
    required String content,
    required String language,
    NotebookLinkType? linkType,
    String? linkId,
    String? linkLabel,
  }) async {
    final repo = ref.read(notebookRepositoryProvider);
    final updated = await repo.update(
      entryId: entryId,
      content: content,
      language: language,
      linkType: linkType,
      linkId: linkId,
      linkLabel: linkLabel,
    );
    state = AsyncData([for (final e in state.value ?? []) if (e.id == entryId) updated else e]);
  }

  Future<void> deleteEntry(String entryId) async {
    final repo = ref.read(notebookRepositoryProvider);
    await repo.delete(entryId);
    state = AsyncData([for (final e in state.value ?? []) if (e.id != entryId) e]);
  }
}
