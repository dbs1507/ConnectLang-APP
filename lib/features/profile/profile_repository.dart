import '../../core/supabase_client.dart';

/// Espelha o `update` de `profiles` em `SubscriberProfilePage.tsx` — só nome
/// e idiomas de estudo. Nível CEFR por idioma é escrito pelo próprio
/// Nivelamento (`placement_write_cefr`), não editável aqui.
class ProfileRepository {
  const ProfileRepository();

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required List<String> studyLanguages,
  }) async {
    await supabase
        .from('profiles')
        .update({'full_name': fullName, 'profile_languages': studyLanguages})
        .eq('id', userId);
  }
}
