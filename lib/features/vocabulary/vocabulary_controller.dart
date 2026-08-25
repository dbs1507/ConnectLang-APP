import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
import 'models/srs_rating.dart';
import 'models/vocabulary_entry.dart';
import 'vocabulary_repository.dart';

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  final userId = ref.watch(authControllerProvider).value?.id;
  if (userId == null) {
    throw StateError('vocabularyRepositoryProvider lido sem usuário autenticado.');
  }
  return VocabularyRepository(userId);
});

final vocabularyControllerProvider =
    AsyncNotifierProvider<VocabularyController, List<VocabularyEntry>>(VocabularyController.new);

class VocabularyController extends AsyncNotifier<List<VocabularyEntry>> {
  @override
  Future<List<VocabularyEntry>> build() {
    return ref.read(vocabularyRepositoryProvider).fetchMine();
  }

  Future<void> addWord({
    required String term,
    required String translation,
    required String language,
    String? description,
    String? context,
    String? example,
    String? partOfSpeech,
  }) async {
    final repo = ref.read(vocabularyRepositoryProvider);
    final entry = await repo.addWord(
      term: term,
      translation: translation,
      language: language,
      description: description,
      context: context,
      example: example,
      partOfSpeech: partOfSpeech,
    );
    state = AsyncData([entry, ...state.value ?? []]);
  }

  Future<void> rate(String entryId, SrsRating rating) async {
    final current = state.value ?? [];
    final entry = current.firstWhere((e) => e.id == entryId);
    final repo = ref.read(vocabularyRepositoryProvider);
    final updated = await repo.rate(entry, rating);
    state = AsyncData([for (final e in current) if (e.id == entryId) updated else e]);
  }

  Future<void> archive(String entryId) async {
    final repo = ref.read(vocabularyRepositoryProvider);
    await repo.archive(entryId);
    state = AsyncData([for (final e in state.value ?? []) if (e.id != entryId) e]);
  }
}
