import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';

/// Compra de assinatura fica só pelo site na v1 (regras de IAP da
/// Apple/Google — docs/planejamento.md, seção 1). Sem link de checkout
/// clicável aqui de propósito.
class SubscriptionInactivePage extends ConsumerWidget {
  const SubscriptionInactivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sua assinatura não está ativa.\nAssine pelo site para continuar estudando.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .refreshProfile(),
                  child: const Text('Já assinei, atualizar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
