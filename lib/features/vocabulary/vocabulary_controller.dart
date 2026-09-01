import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
import 'models/base_vocabulary_entry.dart';
import 'models/srs_rating.dart';
import 'models/vocab_category.dart';
import 'models/vocabulary_entry.dart';
import 'vocabulary_repository.dart';

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  final userId = ref.watch(authControllerProvider).value?.id;
  if (userId == null) {
    throw StateError(
      'vocabularyRepositoryProvider lido sem usuário autenticado.',
    );
  }
  return VocabularyRepository(userId);
});

/// Catálogo global de categorias — mesmo pro Aluno/Assinante, não muda por
/// idioma nem por usuário, então um `FutureProvider` simples basta.
final vocabularyCategoriesProvider = FutureProvider<List<VocabCategory>>((ref) {
  return ref.watch(vocabularyRepositoryProvider).fetchCategories();
});

final vocabularyControllerProvider =
    AsyncNotifierProvider<VocabularyController, List<VocabularyEntry>>(
      VocabularyController.new,
    );

final archivedVocabularyControllerProvider =
    AsyncNotifierProvider<ArchivedVocabularyController, List<VocabularyEntry>>(
      ArchivedVocabularyController.new,
    );

final baseVocabularyProvider =
    FutureProvider.family<List<BaseVocabularyEntry>, String>((ref, language) {
      return ref
          .watch(vocabularyRepositoryProvider)
          .fetchBase(language: language);
    });

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
    List<String> categoryIds = const [],
    VocabEntryKind entryKind = VocabEntryKind.word,
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
      categoryIds: categoryIds,
      entryKind: entryKind,
    );
    state = AsyncData([entry, ...state.value ?? []]);
  }

  Future<void> addFromText({
    required String term,
    required String translation,
    required String language,
    required String source,
    required String context,
    required String description,
    required VocabEntryKind entryKind,
    String? example,
    String? partOfSpeech,
    String? captureSurface,
    String? libraryTextId,
    String? temporaryTextId,
    String? personalTextId,
    List<String> categoryIds = const [],
  }) async {
    final entry = await ref
        .read(vocabularyRepositoryProvider)
        .addFromText(
          term: term,
          translation: translation,
          language: language,
          source: source,
          context: context,
          description: description,
          entryKind: entryKind,
          example: example,
          partOfSpeech: partOfSpeech,
          captureSurface: captureSurface,
          libraryTextId: libraryTextId,
          temporaryTextId: temporaryTextId,
          personalTextId: personalTextId,
          categoryIds: categoryIds,
        );
    state = AsyncData([entry, ...state.value ?? []]);
  }

  Future<void> rate(String entryId, SrsRating rating) async {
    final current = state.value ?? [];
    final entry = current.firstWhere((e) => e.id == entryId);
    final repo = ref.read(vocabularyRepositoryProvider);
    final updated = await repo.rate(entry, rating);
    state = AsyncData([
      for (final e in current)
        if (e.id == entryId) updated else e,
    ]);
  }

  Future<void> archive(String entryId) async {
    final current = state.value ?? [];
    final entry = current.where((e) => e.id == entryId).firstOrNull;
    final repo = ref.read(vocabularyRepositoryProvider);
    await repo.archive(entryId);
    state = AsyncData([
      for (final e in current)
        if (e.id != entryId) e,
    ]);
    if (entry != null) {
      final archived = ref.read(archivedVocabularyControllerProvider).value;
      if (archived != null) {
        ref.read(archivedVocabularyControllerProvider.notifier).prepend(entry);
      }
    }
  }

  Future<void> addFromBase(BaseVocabularyEntry base) async {
    final repo = ref.read(vocabularyRepositoryProvider);
    final entry = await repo.addFromBase(base);
    state = AsyncData([entry, ...state.value ?? []]);
  }

  void prepend(VocabularyEntry entry) {
    final current = state.value;
    if (current == null) return;
    if (current.any((e) => e.id == entry.id)) return;
    state = AsyncData([entry, ...current]);
  }
}

class ArchivedVocabularyController
    extends AsyncNotifier<List<VocabularyEntry>> {
  @override
  Future<List<VocabularyEntry>> build() {
    return ref.read(vocabularyRepositoryProvider).fetchArchived();
  }

  Future<void> restore(String entryId) async {
    final current = state.value ?? [];
    final entry = current.where((e) => e.id == entryId).firstOrNull;
    await ref.read(vocabularyRepositoryProvider).restore(entryId);
    state = AsyncData([
      for (final e in current)
        if (e.id != entryId) e,
    ]);
    if (entry != null) {
      ref.read(vocabularyControllerProvider.notifier).prepend(entry);
    }
  }

  void prepend(VocabularyEntry entry) {
    final current = state.value;
    if (current == null) return;
    if (current.any((e) => e.id == entry.id)) return;
    state = AsyncData([entry, ...current]);
  }
}
