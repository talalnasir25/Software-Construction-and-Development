import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../../domain/models.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/trip_card.dart';
import 'trip_details_screen.dart';

/// Rider: trips I joined, split into upcoming and past.
class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user!;
    return RepoBuilder<List<TripView>>(
      reloadKey: user.id,
      load: (repo) => repo.ridesOf(user.id),
      builder: (context, rides) {
        if (rides.isEmpty) {
          return const EmptyView(
            icon: Icons.event_seat_outlined,
            title: 'No rides yet',
            message: 'Join a trip from "Find rides" and it will show up here.',
          );
        }
        final upcoming = rides.where((v) => v.trip.status == TripStatus.open).toList().reversed;
        final past = rides.where((v) => v.trip.status != TripStatus.open);
        return Constrained(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.xl),
            children: [
              if (upcoming.isNotEmpty) const SectionTitle('Upcoming'),
              for (final v in upcoming) ...[
                TripCard(view: v, onTap: () => openTrip(context, v.trip.id)),
                const SizedBox(height: Gap.m),
              ],
              if (past.isNotEmpty) const SectionTitle('Past and cancelled'),
              for (final v in past) ...[
                TripCard(view: v, onTap: () => openTrip(context, v.trip.id)),
                const SizedBox(height: Gap.m),
              ],
            ],
          ),
        );
      },
    );
  }
}
