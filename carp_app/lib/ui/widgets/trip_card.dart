import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../../domain/models.dart';
import '../format.dart';
import '../../theme/app_theme.dart';
import 'common.dart';

/// Price explanation used on cards and the details screen.
String priceLabel(TripView v, {bool forNewRider = false}) {
  final t = v.trip;
  if (t.pricingMode == PricingMode.perSeat) return '${rs(t.price)} per seat';
  final share = forNewRider ? v.shareIfJoin : v.currentShare;
  final people = forNewRider ? v.joinedCount + 2 : v.joinedCount + 1;
  if (!forNewRider && v.joinedCount == 0) return '${rs(t.price)} total, split with riders';
  return '${rs(share)} each (${rs(t.price)} ÷ $people)';
}

String repeatLabel(Trip t) => switch (t.repeat) {
      TripRepeat.oneTime => 'One-time',
      TripRepeat.daily => 'Daily',
      TripRepeat.weekdays => (t.weekdays.toList()..sort()).map((d) => weekdayNames[d - 1]).join(', '),
    };

/// Status pill for a trip (Open / Full / Confirmed / Edited / Cancelled).
Widget tripStatusPill(BuildContext context, TripView v) => switch (v.trip.status) {
      TripStatus.cancelled => StatusPill('Cancelled', color: context.colors.onSurfaceVariant),
      TripStatus.confirmed when v.trip.isEdited =>
        StatusPill('Confirmed · Edited', color: context.palette.highlightText),
      TripStatus.confirmed => StatusPill('Confirmed', color: context.palette.successText),
      TripStatus.open when v.isFull => StatusPill('Full', color: context.palette.owesText),
      TripStatus.open => StatusPill('Open', color: context.colors.primary),
    };

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.view, required this.onTap, this.forNewRider = false, this.showDriver = true});

  final TripView view;
  final VoidCallback onTap;
  final bool forNewRider;
  final bool showDriver;

  @override
  Widget build(BuildContext context) {
    final t = view.trip;
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(formatDateTime(t.departure),
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  tripStatusPill(context, view),
                ],
              ),
              const SizedBox(height: Gap.m),
              _RouteLine(from: t.from, to: t.to),
              const SizedBox(height: Gap.m),
              Wrap(
                spacing: Gap.m,
                runSpacing: Gap.xs,
                children: [
                  _Meta(t.vehicleType == VehicleType.car ? Icons.directions_car : Icons.two_wheeler,
                      t.vehicleType.label),
                  _Meta(Icons.event_seat_outlined,
                      t.status == TripStatus.open ? '${view.seatsLeft} of ${t.seats} seats left' : '${view.joinedCount} riders'),
                  _Meta(Icons.repeat, repeatLabel(t)),
                ],
              ),
              const Divider(height: Gap.l),
              Row(
                children: [
                  if (showDriver) ...[
                    UserAvatar(initials: view.driver.initials, radius: 14),
                    const SizedBox(width: Gap.s),
                    Expanded(child: Text(view.driver.name, style: muted, overflow: TextOverflow.ellipsis)),
                  ] else
                    const Spacer(),
                  const SizedBox(width: Gap.s),
                  Flexible(
                    flex: 2,
                    child: Text(priceLabel(view, forNewRider: forNewRider),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    return Row(
      children: [
        Column(
          children: [
            Icon(Icons.trip_origin, size: 14, color: scheme.primary),
            Container(width: 2, height: 18, color: scheme.outlineVariant),
            Icon(Icons.location_on, size: 16, color: scheme.tertiary),
          ],
        ),
        const SizedBox(width: Gap.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(from, style: style, overflow: TextOverflow.ellipsis),
              const SizedBox(height: Gap.s),
              Text(to, style: style, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: Gap.xs),
        Text(text, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}
