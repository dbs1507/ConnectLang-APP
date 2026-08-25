/// Espelha `PlacementItemPublic`/`PlacementDimension`/`PlacementItemKind` de
/// `src/lib/placementTest.ts`. O JSON vem pronto do RPC (`placement_public_item`
/// no Postgres) — este model só tipa o que o app usa.
enum PlacementDimension { vocab, grammar, listening, production, dictation }

enum PlacementItemKind { mcq, producaoTraducao, ditado, producaoLivre }

PlacementDimension _dimensionFromRaw(String? raw) {
  switch (raw) {
    case 'grammar':
      return PlacementDimension.grammar;
    case 'listening':
      return PlacementDimension.listening;
    case 'production':
      return PlacementDimension.production;
    case 'dictation':
      return PlacementDimension.dictation;
    case 'vocab':
    default:
      return PlacementDimension.vocab;
  }
}

PlacementItemKind _itemKindFromRaw(String? raw, PlacementDimension dimension) {
  switch (raw) {
    case 'producao_traducao':
      return PlacementItemKind.producaoTraducao;
    case 'ditado':
      return PlacementItemKind.ditado;
    case 'producao_livre':
      return PlacementItemKind.producaoLivre;
    case 'mcq':
      return PlacementItemKind.mcq;
    default:
      if (dimension == PlacementDimension.dictation) return PlacementItemKind.ditado;
      if (dimension == PlacementDimension.production) return PlacementItemKind.producaoTraducao;
      return PlacementItemKind.mcq;
  }
}

class PlacementItem {
  const PlacementItem({
    required this.id,
    required this.language,
    required this.dimension,
    required this.cefr,
    required this.prompt,
    required this.options,
    required this.itemKind,
    this.audioText,
    this.audioUrl,
  });

  final String id;
  final String language;
  final PlacementDimension dimension;
  final String cefr;
  final String prompt;
  final Map<String, String> options;
  final String? audioText;
  final String? audioUrl;
  final PlacementItemKind itemKind;

  /// Item de resposta livre (tradução, ditado ou produção livre) — sem opções A/B/C/D.
  bool get isFreeText => itemKind != PlacementItemKind.mcq;

  bool get isDictation => itemKind == PlacementItemKind.ditado || dimension == PlacementDimension.dictation;

  bool get isProduction =>
      itemKind == PlacementItemKind.producaoTraducao ||
      (dimension == PlacementDimension.production &&
          itemKind != PlacementItemKind.producaoLivre &&
          itemKind != PlacementItemKind.ditado);

  bool get isFreeWriting => itemKind == PlacementItemKind.producaoLivre;

  /// Listening e ditado tocam áudio gerado sob demanda (mesma function do Ditado).
  bool get needsAudio => dimension == PlacementDimension.listening || isDictation;

  factory PlacementItem.fromRow(Map<String, dynamic> row) {
    final dimension = _dimensionFromRaw(row['dimension'] as String?);
    final rawOptions = row['options'];
    final options = rawOptions is Map
        ? rawOptions.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))
        : <String, String>{};
    return PlacementItem(
      id: row['id'] as String,
      language: (row['language'] as String? ?? '').toUpperCase(),
      dimension: dimension,
      cefr: row['cefr'] as String? ?? 'A1',
      prompt: row['prompt'] as String? ?? '',
      options: options,
      itemKind: _itemKindFromRaw(row['itemKind'] as String?, dimension),
      audioText: row['audioText'] as String?,
      audioUrl: row['audioUrl'] as String?,
    );
  }
}
