import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'driver_money_screen.dart';
import 'driver_trips_screen.dart';
import 'find_trips_screen.dart';
import 'my_rides_screen.dart';
import 'post_trip_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

/// One tab in the bottom navigation.
class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.body);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget body;
}

const _mapTab = _Tab(
  'Map',
  Icons.map_outlined,
  Icons.map,
  ComingSoonView(
    icon: Icons.map_outlined,
    title: 'Live map',
    message: 'See routes and pickup points on a map.',
  ),
);

/// Main screen after login. The bottom navigation changes with the mode.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_Tab> _tabs(AppMode mode) => mode == AppMode.rider
      ? const [
          _Tab('Find rides', Icons.search, Icons.search, FindTripsScreen()),
          _Tab('My rides', Icons.event_seat_outlined, Icons.event_seat, MyRidesScreen()),
          _mapTab,
          _Tab('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, WalletScreen()),
          _Tab('Profile', Icons.person_outline, Icons.person, ProfileScreen()),
        ]
      : const [
          _Tab('My trips', Icons.directions_car_outlined, Icons.directions_car, DriverTripsScreen()),
          _mapTab,
          _Tab('Riders', Icons.payments_outlined, Icons.payments, DriverMoneyScreen()),
          _Tab('Profile', Icons.person_outline, Icons.person, ProfileScreen()),
        ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tabs = _tabs(app.mode);
    final index = _index.clamp(0, tabs.length - 1);
    final tab = tabs[index];

    return Scaffold(
      appBar: AppBar(
        title: Text(tab.label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.m),
            child: SegmentedButton<AppMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: AppMode.rider, label: Text('Rider'), icon: Icon(Icons.person_pin_circle_outlined)),
                ButtonSegment(value: AppMode.driver, label: Text('Driver'), icon: Icon(Icons.drive_eta_outlined)),
              ],
              selected: {app.mode},
              onSelectionChanged: (s) {
                setState(() => _index = 0);
                app.setMode(s.first);
              },
            ),
          ),
        ],
      ),
      body: KeyedSubtree(key: ValueKey('${app.mode}-$index'), child: tab.body),
      floatingActionButton: app.isDriver && index == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PostTripScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Post a trip'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs) NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
        ],
      ),
    );
  }
}
