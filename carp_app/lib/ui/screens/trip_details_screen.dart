import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../../domain/models.dart';
import '../../domain/money_rules.dart';
import '../app_state.dart';
import '../format.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/trip_card.dart';

void openTrip(BuildContext context, String tripId) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => TripDetailsScreen(tripId: tripId)));
}

/// Trip details for both sides. What you can do depends on whether you
/// are this trip's driver or a rider.
class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Trip details')),
      body: RepoBuilder<TripView>(
        load: (repo) => repo.tripDetails(tripId),
        builder: (context, v) {
          final isDriver = v.trip.driverId == user.id;
          return Constrained(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.xl),
              children: [
                _Summary(v),
                const SectionTitle('Driver and vehicle'),
                _DriverCard(v),
                if (isDriver)
                  _DriverPanel(
                    key: ValueKey('${v.trip.status}-${v.trip.editHistory.length}-${v.joinedCount}'),
                    view: v,
                  )
                else
                  _RiderPanel(view: v, userId: user.id),
                _ChargesSection(view: v, userId: user.id, isDriver: isDriver),
                if (v.trip.editHistory.isNotEmpty) ...[
                  const SectionTitle('Edit history'),
                  Card(
                    child: Column(children: [
                      for (final e in v.trip.editHistory.reversed)
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(e.summary),
                          subtitle: Text('Edited ${timeAgo(e.at)}'),
                        ),
                    ]),
                  ),
                ],
                if (v.disputes.isNotEmpty) ...[
                  const SectionTitle('Disputes'),
                  Card(
                    child: Column(children: [
                      for (final d in v.disputes)
                        ListTile(
                          leading: Icon(Icons.report_outlined, color: context.palette.owes),
                          title: Text('${d.rider.name} disputed ${rs(d.entry.amount)}'),
                          subtitle: Text('"${d.dispute.reason}" · ${timeAgo(d.dispute.createdAt)}'),
                        ),
                    ]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.v);
  final TripView v;

  @override
  Widget build(BuildContext context) {
    final t = v.trip;
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(formatDateTime(t.departure), style: theme.textTheme.titleMedium)),
              tripStatusPill(context, v),
            ]),
            const SizedBox(height: Gap.s),
            Text('${t.from}  →  ${t.to}',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Gap.m),
            Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
              Chip(avatar: const Icon(Icons.repeat, size: 18), label: Text(repeatLabel(t))),
              Chip(avatar: const Icon(Icons.sell_outlined, size: 18), label: Text(t.pricingMode.label)),
              Chip(
                avatar: const Icon(Icons.event_seat_outlined, size: 18),
                label: Text('${v.joinedCount}/${t.seats} seats taken'),
              ),
            ]),
            const SizedBox(height: Gap.s),
            Text(priceLabel(v), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (t.pricingMode == PricingMode.totalSplit)
              Text('The total is shared equally by the riders and the driver. Amounts are rounded up.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard(this.v);
  final TripView v;

  @override
  Widget build(BuildContext context) {
    final d = v.driver;
    final t = v.trip;
    return Card(
      child: ListTile(
        leading: UserAvatar(initials: d.initials),
        title: Text(d.name),
        subtitle: Text([
          t.vehicleType.label,
          if (d.vehicleModel.isNotEmpty) d.vehicleModel,
          t.plate,
          if (d.phone.isNotEmpty) d.phone,
        ].join(' · ')),
        trailing: Icon(t.vehicleType == VehicleType.car ? Icons.directions_car : Icons.two_wheeler),
      ),
    );
  }
}

// ---------------------------------------------------------------- Rider side

class _RiderPanel extends StatelessWidget {
  const _RiderPanel({required this.view, required this.userId});
  final TripView view;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    final t = view.trip;
    final mine = view.bookingOf(userId);
    final scheme = Theme.of(context).colorScheme;

    // Not on this trip yet.
    if (mine == null) {
      if (t.status != TripStatus.open) return const SizedBox.shrink();
      if (view.isFull) {
        return Padding(
          padding: const EdgeInsets.only(top: Gap.l),
          child: Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.block, color: scheme.onErrorContainer),
              title: Text('This trip is full', style: TextStyle(color: scheme.onErrorContainer)),
              subtitle: Text('All ${t.seats} seat${t.seats == 1 ? ' is' : 's are'} taken. Try another trip.',
                  style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: Gap.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('You will pay about ${rs(view.shareIfJoin)} (final amount is set when the driver confirms attendance).',
                textAlign: TextAlign.center),
            const SizedBox(height: Gap.s),
            BusyButton(
              label: 'Join trip · ${view.seatsLeft} seat${view.seatsLeft == 1 ? '' : 's'} left',
              icon: Icons.add_circle_outline,
              onPressed: () => runAction(context, () => app.repo.joinTrip(t.id, userId),
                  success: 'You joined the trip! Cancel free within 10 minutes.'),
            ),
          ],
        ),
      );
    }

    // Already joined.
    if (t.status != TripStatus.open) {
      final present = mine.booking.present;
      return Padding(
        padding: const EdgeInsets.only(top: Gap.l),
        child: Card(
          child: ListTile(
            leading: Icon(present ? Icons.check_circle : Icons.cancel_outlined,
                color: present ? context.palette.success : scheme.outline),
            title: Text(t.status == TripStatus.cancelled
                ? 'The driver cancelled this trip'
                : 'Driver marked you ${present ? 'PRESENT' : 'ABSENT'}'),
          ),
        ),
      );
    }

    final waited = DateTime.now().difference(mine.booking.joinedAt);
    final freeLeft = CancellationRule.freeWindow - waited;
    final penalty = CancellationRule.riderPenalty(
      joinedAt: mine.booking.joinedAt,
      now: DateTime.now(),
      share: view.currentShare,
    );
    return Padding(
      padding: const EdgeInsets.only(top: Gap.l),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.check_circle, color: context.palette.success),
                const SizedBox(width: Gap.s),
                const Text("You're on this trip", style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: Gap.s),
              Text('Joined ${timeAgo(mine.booking.joinedAt)}. Your share right now: ${rs(view.currentShare)}.'),
              Text(
                penalty == 0
                    ? 'Free cancellation for about ${freeLeft.inMinutes + 1} more min.'
                    : 'Cancelling now costs ${rs(penalty)} (10% of your share), paid to the driver.',
                style: TextStyle(color: penalty == 0 ? context.palette.successText : context.palette.owesText),
              ),
              const SizedBox(height: Gap.m),
              BusyButton(
                outlined: true,
                label: 'Cancel my seat',
                icon: Icons.close,
                onPressed: () async {
                  final ok = await confirmDialog(context,
                      title: 'Cancel your seat?',
                      message: penalty == 0 ? 'This is free.' : 'You will be charged ${rs(penalty)}.',
                      confirmLabel: 'Cancel seat');
                  if (!ok || !context.mounted) return;
                  await runAction(context, () async {
                    final charged = await app.repo.cancelBooking(t.id, userId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(charged == 0 ? 'Cancelled for free.' : 'Cancelled. Penalty: ${rs(charged)}.'),
                      ));
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Driver side

class _DriverPanel extends StatefulWidget {
  const _DriverPanel({super.key, required this.view});
  final TripView view;

  @override
  State<_DriverPanel> createState() => _DriverPanelState();
}

class _DriverPanelState extends State<_DriverPanel> {
  // Local attendance; riders default to PRESENT.
  late final Map<String, bool> _present = {
    for (final b in widget.view.riders) b.rider.id: b.booking.present,
  };

  Set<String> get _presentIds => {for (final e in _present.entries) if (e.value) e.key};

  bool get _changed => widget.view.riders.any((b) => b.booking.present != _present[b.rider.id]);

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final t = v.trip;
    final app = AppScope.read(context);

    if (t.status == TripStatus.cancelled) {
      return const Padding(
        padding: EdgeInsets.only(top: Gap.l),
        child: Card(child: ListTile(leading: Icon(Icons.block), title: Text('You cancelled this trip.'))),
      );
    }

    final confirmed = t.status == TripStatus.confirmed;
    final canEdit = confirmed && AttendanceRule.canEdit(confirmedAt: t.confirmedAt!, now: DateTime.now()).ok;
    final editable = !confirmed || canEdit;
    final preview = CostSplit.chargesFor(
      mode: t.pricingMode,
      price: t.price,
      presentRiderIds: _presentIds.toList(),
    );
    final eachPays = preview.values.isEmpty ? 0 : preview.values.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(confirmed ? 'Attendance' : 'Riders and attendance'),
        if (v.riders.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.people_outline),
              title: Text('No riders yet'),
              subtitle: Text('Confirming with zero attendees creates no charges.'),
            ),
          )
        else
          Card(
            child: Column(children: [
              for (final b in v.riders)
                SwitchListTile(
                  secondary: UserAvatar(initials: b.rider.initials),
                  title: Text(b.rider.name),
                  subtitle: Text(_present[b.rider.id]! ? 'Present' : 'Absent'),
                  value: _present[b.rider.id]!,
                  onChanged: editable ? (on) => setState(() => _present[b.rider.id] = on) : null,
                ),
            ]),
          ),
        const SizedBox(height: Gap.s),
        if (editable && v.riders.isNotEmpty)
          Text(
            preview.isEmpty
                ? 'Nobody present: no one will be charged.'
                : '${preview.length} present × ${rs(eachPays)} each. Absent riders pay nothing.',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: Gap.m),
        if (!confirmed) ...[
          BusyButton(
            label: 'Confirm trip',
            icon: Icons.verified_outlined,
            onPressed: () => runAction(context, () => app.repo.confirmTrip(t.id, _presentIds),
                success: 'Trip confirmed. Charges created for present riders.'),
          ),
          const SizedBox(height: Gap.s),
          BusyButton(
            outlined: true,
            label: 'Cancel trip',
            icon: Icons.cancel_outlined,
            onPressed: () async {
              final credit = Money.percentUp(v.currentShare, CancellationRule.penaltyPercent);
              final ok = await confirmDialog(context,
                  title: 'Cancel this trip?',
                  message: v.riders.isEmpty
                      ? 'No riders have joined, so this is free.'
                      : 'Each of the ${v.joinedCount} riders gets ${rs(credit)} credit from you (10% of their share).',
                  confirmLabel: 'Cancel trip');
              if (!ok || !context.mounted) return;
              await runAction(context, () => app.repo.cancelTrip(t.id, t.driverId), success: 'Trip cancelled.');
            },
          ),
        ] else if (canEdit) ...[
          Text('You can edit attendance until ${formatDateTime(t.confirmedAt!.add(AttendanceRule.editWindow))}.',
              textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: Gap.s),
          BusyButton(
            label: 'Save attendance edit',
            icon: Icons.edit_note,
            onPressed: _changed
                ? () => runAction(context, () => app.repo.editAttendance(t.id, _presentIds),
                    success: 'Saved. Old charges reversed and new charges added.')
                : null,
          ),
        ] else
          const Text('The 24-hour edit window has closed.', textAlign: TextAlign.center),
      ],
    );
  }
}

// ------------------------------------------------------------------ Charges

class _ChargesSection extends StatelessWidget {
  const _ChargesSection({required this.view, required this.userId, required this.isDriver});
  final TripView view;
  final String userId;
  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    // Riders only see their own lines; the driver sees everyone's.
    final entries = isDriver ? view.entries : view.entries.where((e) => e.entry.riderId == userId).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(isDriver ? 'Charges on this trip' : 'My charges on this trip'),
        Card(
          child: Column(children: [
            for (final e in entries) EntryTile(e, showRider: isDriver, allowDispute: !isDriver),
          ]),
        ),
      ],
    );
  }
}

/// One ledger line. Riders get a "Dispute" button within 24 hours.
class EntryTile extends StatelessWidget {
  const EntryTile(this.e, {super.key, this.showRider = false, this.showDriver = false, this.allowDispute = false});

  final EntryView e;
  final bool showRider;
  final bool showDriver;
  final bool allowDispute;

  static IconData iconFor(LedgerType t) => switch (t) {
        LedgerType.charge => Icons.receipt_long_outlined,
        LedgerType.penalty => Icons.gavel_outlined,
        LedgerType.reversal => Icons.undo,
        LedgerType.payment => Icons.payments_outlined,
        LedgerType.credit => Icons.card_giftcard_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final entry = e.entry;
    final canDispute = allowDispute &&
        DisputeRule.canDispute(
          type: entry.type,
          chargedAt: entry.createdAt,
          now: DateTime.now(),
          alreadyDisputed: e.disputed,
        ).ok;
    final who = [if (showRider) e.rider.name, if (showDriver) 'to ${e.driver.name}'].join(' ');

    return ListTile(
      leading: Icon(iconFor(entry.type)),
      title: Text('${entry.type.label}${who.isEmpty ? '' : ' · $who'}'),
      subtitle: Text('${entry.note}\n${formatDateTime(entry.createdAt)}${e.disputed ? ' · Disputed' : ''}'),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            entry.amount > 0 ? '+${rs(entry.amount)}' : rs(entry.amount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: entry.amount > 0 ? context.palette.owesText : context.palette.successText,
            ),
          ),
          if (canDispute)
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
              onPressed: () => _dispute(context),
              child: const Text('Dispute'),
            ),
        ],
      ),
    );
  }

  Future<void> _dispute(BuildContext context) async {
    final app = AppScope.read(context);
    final reason = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispute this charge'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Demo only: the dispute is listed on the trip for review. No money changes.'),
          const SizedBox(height: Gap.m),
          TextField(
            controller: reason,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g. I was present / absent'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send dispute')),
        ],
      ),
    );
    if (send == true && context.mounted) {
      await runAction(context, () => app.repo.disputeCharge(e.entry.id, app.user!.id, reason.text),
          success: 'Dispute sent.');
    }
    reason.dispose();
  }
}
