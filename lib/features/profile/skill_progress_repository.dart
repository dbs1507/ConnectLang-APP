import '../../core/supabase_client.dart';

const _skillLabels = {
  'vocab': 'Vocabulário',
  'grammar': 'Gramática',
  'listening': 'Compreensão oral',
  'articles': 'Artigos',
  'verb_tense': 'Tempos verbais',
  'spelling': 'Ortografia',
  'word_order': 'Ordem das palavras',
  'omission': 'Omissões',
  'addition': 'Palavras a mais',
  'prepositions': 'Preposições',
  'agreement': 'Concordância',
  'phonology_like': 'Sons parecidos',
  'capitalization': 'Maiúsculas',
  'punctuation': 'Pontuação',
  'other': 'Outros',
};

class SkillProgressRow {
  const SkillProgressRow({
    required this.skillId,
    required this.strength,
    required this.crownLevel,
  });

  final String skillId;
  final double strength;
  final int crownLevel;

  String get label => _skillLabels[skillId] ?? skillId;

  factory SkillProgressRow.fromRow(Map<String, dynamic> row) {
    final crowns = (row['crown_level'] as num?)?.toInt() ?? 0;
    return SkillProgressRow(
      skillId: row['skill_id'] as String? ?? '',
      strength: (row['strength'] as num?)?.toDouble() ?? 0,
      crownLevel: crowns.clamp(0, 5),
    );
  }
}

/// RPC `skill_list_progress` — só leitura, igual a `SubscriberSkillProgress.tsx`.
class SkillProgressRepository {
  const SkillProgressRepository();

  Future<List<SkillProgressRow>> fetch(String language) async {
    final data = await supabase.rpc(
      'skill_list_progress',
      params: {'p_language': language},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => SkillProgressRow.fromRow(Map<String, dynamic>.from(row)))
        .where((row) => row.skillId.isNotEmpty)
        .toList();
  }
}
