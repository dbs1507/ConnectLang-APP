import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
import '../study_coach/study_assignments_repository.dart';
import 'library_repository.dart';
import 'models/library_text.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final userId = ref.watch(authControllerProvider).value?.id;
  if (userId == null) {
    throw StateError('libraryRepositoryProvider lido sem usuário autenticado.');
  }
  return LibraryRepository(userId);
});

class LibraryState {
  const LibraryState({
    required this.texts,
    required this.temporaryTexts,
    required this.personalTexts,
    required this.readTextIds,
  });

  final List<LibraryText> texts;
  final List<LibraryText> temporaryTexts;
  final List<LibraryText> personalTexts;
  final Set<String> readTextIds;

  bool isRead(String textId) => readTextIds.contains(textId);

  LibraryState copyWith({
    List<LibraryText>? texts,
    List<LibraryText>? temporaryTexts,
    List<LibraryText>? personalTexts,
    Set<String>? readTextIds,
  }) {
    return LibraryState(
      texts: texts ?? this.texts,
      temporaryTexts: temporaryTexts ?? this.temporaryTexts,
      personalTexts: personalTexts ?? this.personalTexts,
      readTextIds: readTextIds ?? this.readTextIds,
    );
  }
}

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, LibraryState>(
      LibraryController.new,
    );

class LibraryController extends AsyncNotifier<LibraryState> {
  @override
  Future<LibraryState> build() async {
    final repo = ref.read(libraryRepositoryProvider);
    final results = await Future.wait([
      repo.fetchTexts(),
      repo.fetchTemporaryTexts(),
      repo.fetchPersonalTexts(),
      repo.fetchReadTextIds(),
    ]);
    return LibraryState(
      texts: results[0] as List<LibraryText>,
      temporaryTexts: results[1] as List<LibraryText>,
      personalTexts: results[2] as List<LibraryText>,
      readTextIds: results[3] as Set<String>,
    );
  }

  Future<void> toggleRead(LibraryText text) async {
    if (text.isOwned) return;
    final current = state.value;
    if (current == null) return;
    final repo = ref.read(libraryRepositoryProvider);
    final isRead = current.isRead(text.id);

    final optimisticIds = Set<String>.from(current.readTextIds);
    if (isRead) {
      optimisticIds.remove(text.id);
    } else {
      optimisticIds.add(text.id);
    }
    state = AsyncData(current.copyWith(readTextIds: optimisticIds));

    try {
      if (isRead) {
        await repo.markUnread(text.id);
      } else {
        await repo.markRead(text.id);
        unawaited(
          const StudyAssignmentsRepository().completeLibrary(
            language: text.language,
            textId: text.id,
            kinds: const ['read_text'],
          ),
        );
      }
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<LibraryText> createTemporary({
    required String title,
    required String content,
    required String language,
    String? cefr,
  }) async {
    final created = await ref
        .read(libraryRepositoryProvider)
        .createTemporaryText(
          title: title,
          content: content,
          language: language,
          cefr: cefr,
        );
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(temporaryTexts: [created, ...current.temporaryTexts]),
      );
    }
    return created;
  }

  Future<LibraryText> saveTemporaryToPersonal(LibraryText text) async {
    final personal = await ref
        .read(libraryRepositoryProvider)
        .saveTemporaryToPersonal(text.id);
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          temporaryTexts: [
            for (final t in current.temporaryTexts)
              if (t.id != text.id) t,
          ],
          personalTexts: [personal, ...current.personalTexts],
        ),
      );
    }
    return personal;
  }

  Future<void> deleteOwned(LibraryText text) async {
    final repo = ref.read(libraryRepositoryProvider);
    if (text.sourceKind == LibraryTextSource.temporary) {
      await repo.deleteTemporaryText(text.id);
    } else if (text.sourceKind == LibraryTextSource.personal) {
      await repo.deletePersonalText(text.id);
    } else {
      return;
    }
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        temporaryTexts: [
          for (final t in current.temporaryTexts)
            if (t.id != text.id) t,
        ],
        personalTexts: [
          for (final t in current.personalTexts)
            if (t.id != text.id) t,
        ],
      ),
    );
  }
}
