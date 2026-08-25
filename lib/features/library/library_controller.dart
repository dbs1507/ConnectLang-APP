import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
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
  const LibraryState({required this.texts, required this.readTextIds});

  final List<LibraryText> texts;
  final Set<String> readTextIds;

  bool isRead(String textId) => readTextIds.contains(textId);

  LibraryState copyWith({Set<String>? readTextIds}) {
    return LibraryState(texts: texts, readTextIds: readTextIds ?? this.readTextIds);
  }
}

final libraryControllerProvider = AsyncNotifierProvider<LibraryController, LibraryState>(LibraryController.new);

class LibraryController extends AsyncNotifier<LibraryState> {
  @override
  Future<LibraryState> build() async {
    final repo = ref.read(libraryRepositoryProvider);
    final results = await Future.wait([repo.fetchTexts(), repo.fetchReadTextIds()]);
    return LibraryState(
      texts: results[0] as List<LibraryText>,
      readTextIds: results[1] as Set<String>,
    );
  }

  Future<void> toggleRead(String textId) async {
    final current = state.value;
    if (current == null) return;
    final repo = ref.read(libraryRepositoryProvider);
    final isRead = current.isRead(textId);

    final optimisticIds = Set<String>.from(current.readTextIds);
    if (isRead) {
      optimisticIds.remove(textId);
    } else {
      optimisticIds.add(textId);
    }
    state = AsyncData(current.copyWith(readTextIds: optimisticIds));

    try {
      if (isRead) {
        await repo.markUnread(textId);
      } else {
        await repo.markRead(textId);
      }
    } catch (_) {
      state = AsyncData(current);
    }
  }
}
