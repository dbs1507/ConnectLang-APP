import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
import '../notebook/notebook_fab.dart';
import '../../core/session/subscription_info.dart';

/// Espelha só a parte de leitura de `SubscriptionPage.tsx` — plano, status e
/// próxima cobrança/fim do trial. Fora do escopo: cancelar, trocar cartão,
/// renovar, histórico de pagamentos e o checkout (ver seção 1 do
/// planejamento.md — compra de assinatura fica só no site).
class SubscriptionStatusPage extends ConsumerWidget {
  const SubscriptionStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(authControllerProvider).value?.subscription;

    return Scaffold(
      floatingActionButton: const NotebookFab(),
      appBar: AppBar(title: const Text('Assinatura')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: subscription == null
              ? const Text('Nenhuma assinatura encontrada.')
              : _SubscriptionCard(subscription: subscription),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final SubscriptionInfo subscription;

  String _planLabel(String? plan) {
    switch (plan) {
      case 'monthly':
        return 'Plano mensal';
      case 'annual':
        return 'Plano anual';
      default:
        return 'Plano';
    }
  }

  String _statusLabel(SubscriptionStatus? status) {
    switch (status) {
      case SubscriptionStatus.trialing:
        return 'Em teste gratuito';
      case SubscriptionStatus.active:
        return 'Ativa';
      case SubscriptionStatus.overdue:
        return 'Pagamento atrasado';
      case SubscriptionStatus.canceled:
        return 'Cancelada';
      case SubscriptionStatus.expired:
        return 'Expirada';
      case null:
        return 'Sem assinatura';
    }
  }

  Color _statusColor(BuildContext context, SubscriptionStatus? status) {
    switch (status) {
      case SubscriptionStatus.trialing:
      case SubscriptionStatus.active:
        return Colors.green.shade700;
      case SubscriptionStatus.overdue:
        return Colors.orange.shade800;
      default:
        return Theme.of(context).colorScheme.error;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isTrialing = subscription.status == SubscriptionStatus.trialing;
    final chargeDate = isTrialing
        ? subscription.trialEndsAt
        : subscription.nextDueDate;
    final chargeLabel = isTrialing ? 'Teste termina em' : 'Próxima cobrança';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _planLabel(subscription.plan),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(
                      context,
                      subscription.status,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(subscription.status),
                    style: TextStyle(
                      color: _statusColor(context, subscription.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (chargeDate != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('$chargeLabel: ${_formatDate(chargeDate)}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Pra alterar forma de pagamento, cancelar ou trocar de plano, acesse sua conta pelo site do ConnectLang.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
