import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../../domain/models.dart';
import '../app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/trip_card.dart';
import 'trip_details_screen.dart';

/// Driver: my posted trips. "Post a trip" is the floating button.
class DriverTripsScreen extends StatelessWidget {
  const DriverTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user!;
    return RepoBuilder<List<TripView>>(
      reloadKey: user.id,
      load: (repo) => repo.tripsOfDriver(user.id),
      builder: (context, trips) {
        if (trips.isEmpty) {
          return const EmptyView(
            icon: Icons.directions_car_outlined,
            title: 'No trips posted yet',
            message: 'Tap "Post a trip" to offer seats to other students.',
          );
        }
        final open = trips.where((v) => v.trip.status == TripStatus.open).toList().reversed;
        final done = trips.where((v) => v.trip.status != TripStatus.open);
        return Constrained(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, 96),
            children: [
              if (open.isNotEmpty) const SectionTitle('Open (tap to mark attendance and confirm)'),
              for (final v in open) ...[
                TripCard(view: v, showDriver: false, onTap: () => openTrip(context, v.trip.id)),
                const SizedBox(height: Gap.m),
              ],
              if (done.isNotEmpty) const SectionTitle('Confirmed and cancelled'),
              for (final v in done) ...[
                TripCard(view: v, showDriver: false, onTap: () => openTrip(context, v.trip.id)),
                const SizedBox(height: Gap.m),
              ],
            ],
          ),
        );
      },
    );
  }
}
