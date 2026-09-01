/// Espelha `SRSRating` de `src/data/mockData.ts` no web.
enum SrsRating {
  again,
  hard,
  good,
  easy;

  static SrsRating? fromRaw(String? raw) {
    if (raw == null) return null;
    for (final rating in SrsRating.values) {
      if (rating.name == raw) return rating;
    }
    return null;
  }

  String get label => switch (this) {
    SrsRating.again => 'De novo',
    SrsRating.hard => 'Difícil',
    SrsRating.good => 'Bom',
    SrsRating.easy => 'Fácil',
  };
}
