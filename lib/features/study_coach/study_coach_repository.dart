import '../../core/supabase_client.dart';
import 'models/production_assignment.dart';
import 'models/study_coach_plan.dart';

/// Espelha `src/lib/studyCoach.ts` + `src/lib/correctSentence.ts`, reduzido:
/// sem cache em `localStorage`/`sessionStorage`, sem histórico de planos
/// anteriores, sem localização do conteúdo por idioma da UI (o app mobile só
/// pede/mostra em português). O plano em cache é lido direto de
/// `subscriber_daily_study_plans`; gerar/atualizar chama a edge function
/// `study-coach` (mesma function do site).
class StudyCoachRepository {
  const StudyCoachRepository();

  /// Último plano salvo pro idioma de estudo pedido (sem chamar IA).
  Future<StudyCoachPlan?> fetchCachedPlan(String studyLanguage) async {
    final rows = await supabase
        .from('subscriber_daily_study_plans')
        .select('payload, refreshed_at, created_at')
        .order('refreshed_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(12);

    for (final row in (rows as List)) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      final payloadMap = Map<String, dynamic>.from(payload);
      final planLanguage = (payloadMap['studyLanguage'] as String?)?.toUpperCase();
      if (planLanguage != null && planLanguage != studyLanguage) continue;
      final plan = StudyCoachPlan.fromRow(payloadMap);
      if (plan != null) return plan;
    }
    return null;
  }

  /// Gera/atualiza o plano do dia via IA (`refresh: true`).
  Future<StudyCoachPlan> generatePlan(String studyLanguage) async {
    final response = await supabase.functions.invoke(
      'study-coach',
      body: {
        'refresh': true,
        'uiLanguage': 'pt',
        'studyLanguage': studyLanguage,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('Resposta inválida do plano de estudos.');
    }
    final plan = StudyCoachPlan.fromRow(Map<String, dynamic>.from(data));
    if (plan == null) throw StateError('Não foi possível gerar o plano de estudos.');
    return plan;
  }

  Future<ProductionAssignment?> fetchAssignment(String id) async {
    final row = await supabase
        .from('subscriber_study_assignments')
        .select('id, language, kind, status, payload')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ProductionAssignment.fromRow(row);
  }

  /// Edge function `correct-sentence` — corrige a produção e (server-side)
  /// marca a assignment como `done` quando `assignmentId` é passado.
  Future<CorrectSentenceResult> gradeProduction({
    required String sentence,
    required String language,
    required String? cefr,
    required String assignmentId,
  }) async {
    final response = await supabase.functions.invoke(
      'correct-sentence',
      body: {
        'sentence': sentence,
        'language': language,
        'uiLanguage': 'pt',
        'cefr': cefr,
        'assignmentId': assignmentId,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('Resposta inválida da correção.');
    }
    final result = CorrectSentenceResult.fromRow(Map<String, dynamic>.from(data));
    if (result == null) throw StateError('Não foi possível corrigir o texto.');
    return result;
  }
}

/// Extrai o id da assignment de uma rota tipo `/estudo/producao-demanda/{id}`.
String? productionAssignmentIdFromRoute(String route) {
  final match = RegExp(r'/producao-demanda/([^/?]+)').firstMatch(route);
  return match?.group(1);
}
