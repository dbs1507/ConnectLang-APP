import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../theme/app_colors.dart';

/// Modal full-screen — pra mini-fluxos com etapas: onboarding, teste de
/// nivelamento, configuração de conta. Cobre 100% da tela, botão de
/// fechar sempre no topo (nunca gesto de swipe-to-dismiss como único
/// jeito de sair — previne fechamento acidental no meio de um fluxo,
/// heurística de Nielsen de prevenção de erro).
Future<T?> showAppFullscreenModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
}) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _FullscreenModalScaffold(
        title: title,
        builder: builder,
      ),
    ),
  );
}

class _FullscreenModalScaffold extends StatelessWidget {
  const _FullscreenModalScaffold({required this.title, required this.builder});

  final String? title;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title == null ? null : Text(title!),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          color: AppColors.heading,
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(child: builder(context)),
    );
  }
}
