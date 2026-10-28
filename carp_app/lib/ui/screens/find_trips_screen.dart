import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/trip_card.dart';
import 'trip_details_screen.dart';

/// Rider: browse upcoming open trips, with a simple text search.
class FindTripsScreen extends StatefulWidget {
  const FindTripsScreen({super.key});

  @override
  State<FindTripsScreen> createState() => _FindTripsScreenState();
}

class _FindTripsScreenState extends State<FindTripsScreen> {
  String _query = '';

  bool _matches(TripView v) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final t = v.trip;
    return '${t.from} ${t.to} ${v.driver.name}'.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user!;
    return RepoBuilder<List<TripView>>(
      reloadKey: user.id,
      load: (repo) => repo.browseTrips(user.id),
      builder: (context, trips) {
        final shown = trips.where(_matches).toList();
        return Constrained(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.xl),
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by place or driver, e.g. G-11',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: Gap.m),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: Gap.xl),
                  child: EmptyView(
                    icon: Icons.directions_car_outlined,
                    title: 'No trips found',
                    message: 'Try another search, or check back later.',
                  ),
                ),
              for (final v in shown) ...[
                TripCard(
                  view: v,
                  forNewRider: v.bookingOf(user.id) == null,
                  onTap: () => openTrip(context, v.trip.id),
                ),
                const SizedBox(height: Gap.m),
              ],
            ],
          ),
        );
      },
    );
  }
}
