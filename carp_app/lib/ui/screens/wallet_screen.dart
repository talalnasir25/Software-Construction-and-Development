import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../../domain/models.dart';
import '../app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/payment_dialog.dart';
import 'trip_details_screen.dart';

/// Rider: read-only balance, balance per driver, payments and full history.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.user!;
    return RepoBuilder<MoneySummary>(
      reloadKey: user.id,
      load: (repo) => repo.riderMoney(user.id),
      builder: (context, m) {
        if (m.entries.isEmpty && m.payments.isEmpty) {
          return const EmptyView(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Nothing here yet',
            message: 'Charges appear after a driver confirms a trip you joined.',
          );
        }
        return Constrained(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.xl),
            children: [
              BalanceHero(
                title: m.total > 0 ? 'You owe in total' : (m.total < 0 ? 'Your credit' : 'All settled'),
                amount: m.total,
                note: 'Read-only. Pay drivers outside the app (Cash, JazzCash, Easypaisa, NayaPay), '
                    'then tap "I paid" so they can confirm.',
              ),
              const SectionTitle('By driver'),
              Card(
                child: Column(children: [
                  for (final p in m.parties)
                    ListTile(
                      leading: UserAvatar(initials: p.user.initials),
                      title: Text(p.user.name),
                      subtitle: BalanceText(p.balance, owesLabel: 'you owe'),
                      trailing: OutlinedButton(
                        onPressed: () => showPaymentDialog(
                          context,
                          title: 'I paid ${p.user.name}',
                          subtitle: 'This stays PENDING until ${p.user.name} confirms it.',
                          suggested: p.balance,
                          onSubmit: (amount, method) => app.repo.markPaid(
                            riderId: user.id,
                            driverId: p.user.id,
                            amount: amount,
                            method: method,
                          ),
                        ).then((ok) {
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Payment sent for confirmation (pending).')));
                          }
                        }),
                        child: const Text('I paid'),
                      ),
                    ),
                ]),
              ),
              if (m.payments.isNotEmpty) ...[
                const SectionTitle('My payments'),
                Card(child: Column(children: [for (final p in m.payments) PaymentTile(p, showDriver: true)])),
              ],
              const SectionTitle('Full history'),
              Card(
                child: Column(children: [
                  for (final e in m.entries)
                    InkWell(
                      onTap: e.entry.tripId == null ? null : () => openTrip(context, e.entry.tripId!),
                      child: EntryTile(e, showDriver: true, allowDispute: true),
                    ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Big balance card at the top of the money screens.
class BalanceHero extends StatelessWidget {
  const BalanceHero({super.key, required this.title, required this.amount, required this.note});

  final String title;
  final int amount;
  final String note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85))),
            const SizedBox(height: Gap.xs),
            Text(rs(amount.abs()),
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: Gap.s),
            Text(note, style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// One payment with its status (Pending / Confirmed / Rejected).
class PaymentTile extends StatelessWidget {
  const PaymentTile(this.p, {super.key, this.showDriver = false, this.showRider = false, this.actions});

  final PaymentView p;
  final bool showDriver;
  final bool showRider;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final pay = p.payment;
    final pill = switch (pay.status) {
      PaymentStatus.pending => const StatusPill('Pending', color: CarpColors.accent),
      PaymentStatus.confirmed => const StatusPill('Confirmed', color: CarpColors.credit),
      PaymentStatus.rejected => const StatusPill('Rejected', color: CarpColors.owes),
    };
    final who = showDriver ? 'to ${p.driver.name}' : (showRider ? 'from ${p.rider.name}' : '');
    return ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: Text('${rs(pay.amount)} via ${pay.method.label} $who'),
      subtitle: Text(formatDateTime(pay.createdAt)),
      trailing: actions ?? pill,
    );
  }
}
