import '../../core/supabase_client.dart';
import 'models/placement_result.dart';
import 'models/placement_retake_status.dart';
import 'models/placement_scoring.dart';

/// Espelha `src/lib/placementTest.ts` — o caminho "test" (adaptativo) e
/// "start_zero" ("começar do zero"), com checagem de cooldown de retake pra
/// ambos os papéis. Fica fora desta fatia: pedido de retake do aluno de
/// escola pro professor (`placementRetakeRequest.ts`), atalho pra sugestão
/// do Coach, e as ferramentas de admin (gerar itens com IA, reparar
/// duplicatas, matriz de cobertura).
///
/// Os RPCs (`security definer`) resolvem o usuário via `auth.uid()`, então o
/// repositório não precisa do id do estudante — diferente do Ditado, que
/// grava `student_id` direto numa tabela.
class PlacementRepository {
  const PlacementRepository();

  Map<String, dynamic> _asRow(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  Future<bool> isLanguageReady(String language) async {
    final data = await supabase.rpc('placement_language_ready', params: {'p_language': language});
    return data == true;
  }

  /// `placement_can_retake` (assinante, cooldown de 14 dias/15 práticas com
  /// janela de graça de 72h) ou `placement_can_retake_student` (aluno de
  /// escola, liberado só por concessão do professor) — a mesma escolha de
  /// RPC que o web faz por `isStudentRole`.
  Future<PlacementRetakeStatus> fetchCanRetake({required String language, required bool isStudent}) async {
    try {
      final data = isStudent
          ? await supabase.rpc('placement_can_retake_student', params: {'p_language': language, 'p_user_id': null})
          : await supabase.rpc('placement_can_retake', params: {'p_language': language, 'p_suggestion_id': null});
      return PlacementRetakeStatus.fromRow(_asRow(data));
    } catch (_) {
      return PlacementRetakeStatus.allowedFallback;
    }
  }

  Future<PlacementStepResult> startTest(String language) async {
    final data = await supabase.rpc('placement_start_test', params: {'p_language': language});
    return PlacementStepResult.fromRow(_asRow(data), fallbackLanguage: language);
  }

  /// "Começar do zero": pula o teste e define o nível como A1 direto.
  Future<PlacementStepResult> startZero(String language) async {
    final data = await supabase.rpc('placement_start_zero', params: {'p_language': language});
    return PlacementStepResult.fromRow(_asRow(data), fallbackLanguage: language);
  }

  Future<PlacementStepResult> submitAnswer({
    required String sessionId,
    required String itemId,
    required String chosenOption,
    required String fallbackLanguage,
  }) async {
    final data = await supabase.rpc('placement_submit_answer', params: {
      'p_session_id': sessionId,
      'p_item_id': itemId,
      'p_chosen_option': chosenOption,
    });
    return PlacementStepResult.fromRow(_asRow(data), fallbackLanguage: fallbackLanguage);
  }

  Future<PlacementStepResult> submitProduction({
    required String sessionId,
    required String itemId,
    required String freeText,
    required String fallbackLanguage,
    String? productionCefr,
  }) async {
    final data = await supabase.rpc('placement_submit_production', params: {
      'p_session_id': sessionId,
      'p_item_id': itemId,
      'p_free_text': freeText,
      'p_production_cefr': productionCefr,
    });
    return PlacementStepResult.fromRow(_asRow(data), fallbackLanguage: fallbackLanguage);
  }

  /// Juiz LLM (edge function `placement-grade-production`) pra tradução/produção
  /// livre. Ditado não passa por aqui — nota vem só da correção local.
  Future<PlacementProductionGrade?> gradeProduction({
    required String answer,
    required String language,
    required String promptCefr,
    String? sourcePt,
    bool freeWriting = false,
    String? taskPrompt,
  }) async {
    final response = await supabase.functions.invoke(
      'placement-grade-production',
      body: {
        'sourcePt': sourcePt,
        'answer': answer,
        'language': language,
        'promptCefr': promptCefr,
        'mode': freeWriting ? 'free_writing' : 'translation',
        'taskPrompt': taskPrompt,
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    return PlacementProductionGrade.fromRow(Map<String, dynamic>.from(data));
  }

  /// Mesma edge function `tts-generate` usada pelo Ditado — listening e
  /// ditado do nivelamento tocam áudio gerado sob demanda.
  Future<String?> fetchAudioUrl({required String text, required String language}) async {
    final response = await supabase.functions.invoke(
      'tts-generate',
      body: {
        'text': text,
        'language': language,
        'origin': 'base',
        'voiceGender': 'female',
        'delivery': 'url',
      },
    );
    final data = response.data;
    if (data is Map && data['audioUrl'] is String) return data['audioUrl'] as String;
    return null;
  }
}

class PlacementProductionGrade {
  const PlacementProductionGrade({
    required this.productionCefr,
    required this.tags,
    required this.rationale,
    required this.modelTranslation,
    required this.showModel,
  });

  final String? productionCefr;
  final List<String> tags;
  final String rationale;
  final String modelTranslation;
  final bool showModel;

  factory PlacementProductionGrade.fromRow(Map<String, dynamic> row) {
    final cefr = (row['productionCefr'] as String?)?.toUpperCase();
    final valid = cefr != null && placementCefrLadder.contains(cefr);
    return PlacementProductionGrade(
      productionCefr: valid ? cefr : null,
      tags: (row['tags'] as List?)?.map((e) => e.toString()).take(2).toList() ?? const [],
      rationale: (row['rationale'] as String? ?? '').trim(),
      modelTranslation: (row['modelTranslation'] as String? ?? '').trim(),
      showModel: row['showModel'] == true,
    );
  }
}
