import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/session/auth_controller.dart';
import 'core/session/user_scoped_data.dart';
import 'core/supabase_client.dart';
import 'design_system/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.init();
  runApp(const ProviderScope(child: ConnectLangApp()));
}

class ConnectLangApp extends ConsumerWidget {
  const ConnectLangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous == next) return;
      if (previous == null) return;
      invalidateUserScopedData(ref);
    });
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'ConnectLang',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
