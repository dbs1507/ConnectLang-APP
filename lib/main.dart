import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.init();
  runApp(const ConnectLangApp());
}

class ConnectLangApp extends StatelessWidget {
  const ConnectLangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConnectLang',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const _BootstrapCheckPage(),
    );
  }
}

/// Placeholder inicial: só confirma que o app conectou ao mesmo projeto
/// Supabase do site. As telas reais (auth, ditado, vocabulário, biblioteca...)
/// entram feature por feature, seguindo lib/features/.
class _BootstrapCheckPage extends StatelessWidget {
  const _BootstrapCheckPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ConnectLang')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase inicializado.\nPróximo passo: tela de login (lib/features/auth).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
