import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/trip_draft.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Profile and settings, plus the "Demo: switch user" helper.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.user!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Constrained(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.xl),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: Row(children: [
                UserAvatar(initials: user.initials, radius: 32),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text(user.email, style: TextStyle(color: scheme.onSurfaceVariant)),
                    if (user.phone.isNotEmpty) Text(user.phone, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editProfile(context, user),
                ),
              ]),
            ),
          ),

          const SectionTitle('Vehicle'),
          Card(
            child: ListTile(
              leading: Icon(user.vehicleType == VehicleType.bike ? Icons.two_wheeler : Icons.directions_car),
              title: Text(user.vehicleType == null ? 'No vehicle added' : '${user.vehicleType!.label} · ${user.plate}'),
              subtitle: Text(user.vehicleModel.isEmpty ? 'Add a vehicle to drive' : user.vehicleModel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editVehicle(context, user),
            ),
          ),

          const SectionTitle('Language'),
          Card(
            child: RadioGroup<String>(
              groupValue: 'en',
              onChanged: (_) {},
              child: const Column(children: [
                RadioListTile<String>(value: 'en', title: Text('English')),
                RadioListTile<String>(value: 'ur', enabled: false, title: Text('Urdu – Coming soon')),
              ]),
            ),
          ),

          const SizedBox(height: Gap.l),
          Card(
            color: CarpColors.accent.withValues(alpha: 0.15),
            child: const ListTile(
              leading: Icon(Icons.workspace_premium, color: CarpColors.accent, size: 32),
              title: Text('Carp Pro – Coming soon', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('More than 2 trips per day, priority listing and more.'),
            ),
          ),

          const SectionTitle('Demo: switch user'),
          Card(
            child: RepoBuilder<List<AppUser>>(
              load: (repo) => repo.demoUsers(),
              builder: (context, users) => Column(children: [
                for (final u in users)
                  ListTile(
                    leading: UserAvatar(initials: u.initials),
                    title: Text(u.name),
                    subtitle: Text(u.vehicleType == null ? 'Rider' : 'Driver · ${u.vehicleType!.label}'),
                    trailing: u.id == user.id
                        ? const StatusPill('You', color: CarpColors.seed)
                        : const Icon(Icons.swap_horiz),
                    onTap: u.id == user.id ? null : () => app.signIn(u),
                  ),
              ]),
            ),
          ),

          const SizedBox(height: Gap.l),
          OutlinedButton.icon(
            onPressed: app.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, AppUser user) async {
    final app = AppScope.read(context);
    final name = TextEditingController(text: user.name);
    final phone = TextEditingController(text: user.phone);
    final save = await _formDialog(context, 'Edit profile', [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
      const SizedBox(height: Gap.m),
      TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone', hintText: '03xx-xxxxxxx')),
    ]);
    if (save && context.mounted) {
      if (name.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      } else {
        user
          ..name = name.text.trim()
          ..phone = phone.text.trim();
        await runAction(context, () => app.repo.updateProfile(user), success: 'Profile saved.');
      }
    }
    name.dispose();
    phone.dispose();
  }

  Future<void> _editVehicle(BuildContext context, AppUser user) async {
    final app = AppScope.read(context);
    final model = TextEditingController(text: user.vehicleModel);
    final plate = TextEditingController(text: user.plate);
    var type = user.vehicleType ?? VehicleType.car;
    final save = await _formDialog(context, 'Vehicle info', [
      StatefulBuilder(
        builder: (context, setState) => SegmentedButton<VehicleType>(
          segments: const [
            ButtonSegment(value: VehicleType.car, label: Text('Car')),
            ButtonSegment(value: VehicleType.bike, label: Text('Bike')),
          ],
          selected: {type},
          onSelectionChanged: (s) => setState(() => type = s.first),
        ),
      ),
      const SizedBox(height: Gap.m),
      TextField(controller: model, decoration: const InputDecoration(labelText: 'Model and color', hintText: 'e.g. Suzuki Alto (silver)')),
      const SizedBox(height: Gap.m),
      TextField(controller: plate, decoration: const InputDecoration(labelText: 'Number plate', hintText: 'e.g. LEA-1234')),
    ]);
    if (save && context.mounted) {
      final error = TripValidator.plate(plate.text);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } else {
        user
          ..vehicleType = type
          ..vehicleModel = model.text.trim()
          ..plate = plate.text.trim().toUpperCase();
        await runAction(context, () => app.repo.updateProfile(user), success: 'Vehicle saved.');
      }
    }
    model.dispose();
    plate.dispose();
  }

  Future<bool> _formDialog(BuildContext context, String title, List<Widget> fields) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: fields)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    return result ?? false;
  }
}
