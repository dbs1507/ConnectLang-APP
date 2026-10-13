import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/library_controller.dart';
import '../../features/notebook/notebook_controller.dart';
import '../../features/vocabulary/vocabulary_controller.dart';

void invalidateUserScopedData(WidgetRef ref) {
  ref.invalidate(vocabularyControllerProvider);
  ref.invalidate(archivedVocabularyControllerProvider);
  ref.invalidate(baseVocabularyProvider);
  ref.invalidate(libraryControllerProvider);
  ref.invalidate(notebookControllerProvider);
}
