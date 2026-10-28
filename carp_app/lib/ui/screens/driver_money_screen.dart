import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../../domain/models.dart';
import '../app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/payment_dialog.dart';
import 'trip_details_screen.dart';
import 'wallet_screen.dart';

/// Driver: each rider's balance across my trips, pending payments to
/// confirm, and a button to record a payment directly.
class DriverMoneyScreen extends StatelessWidget {
  const DriverMoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.user!;
    return RepoBuilder<MoneySummary>(
      reloadKey: user.id,
      load: (repo) => repo.driverMoney(user.id),
      builder: (context, m) {
        if (m.parties.isEmpty && m.payments.isEmpty) {
          return const EmptyView(
            icon: Icons.payments_outlined,
            title: 'No rider balances yet',
            message: 'Balances appear after you confirm a trip with riders.',
          );
        }
        return Constrained(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.xl),
            children: [
              BalanceHero(
                title: m.total >= 0 ? 'Riders owe you' : 'You owe riders (credit)',
                amount: m.total,
                note: 'Payments happen outside the app. Confirm what riders say they paid, '
                    'or record a payment yourself.',
              ),
              if (m.pending.isNotEmpty) ...[
                const SectionTitle('Waiting for your confirmation'),
                Card(
                  child: Column(children: [
                    for (final p in m.pending)
                      PaymentTile(
                        p,
                        showRider: true,
                        actions: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Reject',
                            icon: Icon(Icons.close, color: context.palette.owes),
                            onPressed: () => runAction(context, () => app.repo.rejectPayment(p.payment.id),
                                success: 'Payment rejected.'),
                          ),
                          IconButton.filled(
                            tooltip: 'Confirm',
                            icon: const Icon(Icons.check),
                            onPressed: () => runAction(context, () => app.repo.confirmPayment(p.payment.id),
                                success: 'Payment confirmed.'),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ],
              const SectionTitle('Rider balances'),
              Card(
                child: Column(children: [
                  for (final p in m.parties)
                    ListTile(
                      leading: UserAvatar(initials: p.user.initials),
                      title: Text(p.user.name),
                      subtitle: BalanceText(p.balance),
                      trailing: OutlinedButton(
                        onPressed: () => showPaymentDialog(
                          context,
                          title: 'Record payment from ${p.user.name}',
                          subtitle: 'Recorded by you, so it counts straight away.',
                          suggested: p.balance,
                          onSubmit: (amount, method) => app.repo.recordPayment(
                            riderId: p.user.id,
                            driverId: user.id,
                            amount: amount,
                            method: method,
                          ),
                        ),
                        child: const Text('Record'),
                      ),
                    ),
                ]),
              ),
              if (m.payments.any((p) => p.payment.status != PaymentStatus.pending)) ...[
                const SectionTitle('Payment history'),
                Card(
                  child: Column(children: [
                    for (final p in m.payments.where((p) => p.payment.status != PaymentStatus.pending))
                      PaymentTile(p, showRider: true),
                  ]),
                ),
              ],
              const SectionTitle('All entries'),
              Card(
                child: Column(children: [
                  for (final e in m.entries)
                    InkWell(
                      onTap: e.entry.tripId == null ? null : () => openTrip(context, e.entry.tripId!),
                      child: EntryTile(e, showRider: true),
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
