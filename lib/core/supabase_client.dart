import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mesmo projeto Supabase do web (verb-flow-hub) — não é um backend novo.
/// URL e chave publishable vêm de assets/.env (não versionado; ver assets/.env.example).
class SupabaseBootstrap {
  static Future<void> init() async {
    await dotenv.load(fileName: 'assets/.env');

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_PUBLISHABLE_DEFAULT_KEY'];

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_PUBLISHABLE_DEFAULT_KEY ausentes em assets/.env. '
        'Copie assets/.env.example para assets/.env e preencha com os mesmos valores '
        'de VITE_SUPABASE_URL / VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY do repo web.',
      );
    }

    await Supabase.initialize(url: url, publishableKey: anonKey);
  }
}

SupabaseClient get supabase => Supabase.instance.client;
