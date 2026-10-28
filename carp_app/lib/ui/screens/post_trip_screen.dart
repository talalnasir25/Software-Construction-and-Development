import 'package:flutter/material.dart';

import '../../data/carp_repository.dart';
import '../../domain/models.dart';
import '../../domain/money_rules.dart';
import '../../domain/trip_draft.dart';
import '../app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Driver: post a new trip. All checks come from TripValidator.
class PostTripScreen extends StatefulWidget {
  const PostTripScreen({super.key});

  @override
  State<PostTripScreen> createState() => _PostTripScreenState();
}

class _PostTripScreenState extends State<PostTripScreen> {
  final _form = GlobalKey<FormState>();
  final _draft = TripDraft();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _plate = TextEditingController();
  final _price = TextEditingController();
  bool _submitted = false; // show date/weekday errors only after first try

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefill vehicle info from the profile.
    final user = AppScope.read(context).user!;
    if (_plate.text.isEmpty && user.plate.isNotEmpty) {
      _plate.text = user.plate;
      _draft.vehicleType = user.vehicleType ?? VehicleType.car;
      _draft.seats = _draft.vehicleType.maxSeats == 1 ? 1 : 3;
    }
  }

  @override
  void dispose() {
    for (final c in [_from, _to, _plate, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      initialDate: _draft.date ?? now,
    );
    if (picked != null) setState(() => _draft.date = picked);
  }

  Future<void> _pickTime() async {
    final t = _draft.timeOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: t == null ? const TimeOfDay(hour: 8, minute: 0) : TimeOfDay(hour: t ~/ 60, minute: t % 60),
    );
    if (picked != null) setState(() => _draft.timeOfDay = picked.hour * 60 + picked.minute);
  }

  void _setVehicle(VehicleType type) {
    setState(() {
      _draft.vehicleType = type;
      if (_draft.seats > type.maxSeats) _draft.seats = type.maxSeats;
    });
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    _draft
      ..from = _from.text
      ..to = _to.text
      ..plate = _plate.text
      ..price = int.tryParse(_price.text.trim());
    final formOk = _form.currentState!.validate();
    final others = [
      TripValidator.departure(_draft.departure, DateTime.now()),
      TripValidator.weekdays(_draft.repeat, _draft.weekdays),
    ].whereType<String>();
    if (!formOk || others.isNotEmpty) {
      _snack(others.isNotEmpty ? others.first : 'Please fix the highlighted fields.');
      return;
    }

    final app = AppScope.read(context);
    try {
      await app.repo.postTrip(app.user!.id, _draft);
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Trip posted! Riders can now join.');
    } on CarpException catch (e) {
      if (!mounted) return;
      if (e.message == TripLimitRule.limitMessage) {
        _showLimitDialog();
      } else {
        _snack(e.message);
      }
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _showLimitDialog() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.workspace_premium_outlined, size: 40, color: CarpColors.accent),
          title: const Text('Daily limit reached'),
          content: const Text(TripLimitRule.limitMessage, textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    final scheme = Theme.of(context).colorScheme;
    final dateError = _submitted ? TripValidator.departure(d.departure, DateTime.now()) : null;
    final dayError = _submitted ? TripValidator.weekdays(d.repeat, d.weekdays) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Post a trip')),
      body: Form(
        key: _form,
        autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: Constrained(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.xl),
            children: [
              const SectionTitle('Route'),
              TextFormField(
                controller: _from,
                decoration: const InputDecoration(labelText: 'From', hintText: 'e.g. G-11 Markaz', prefixIcon: Icon(Icons.trip_origin)),
                validator: (v) => TripValidator.place(v ?? '', 'From'),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _to,
                decoration: const InputDecoration(labelText: 'To', hintText: 'e.g. COMSATS Park Road', prefixIcon: Icon(Icons.location_on_outlined)),
                validator: (v) => TripValidator.place(v ?? '', 'To') ?? TripValidator.route(_from.text, v ?? ''),
              ),

              const SectionTitle('When'),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(d.date == null ? 'Pick date' : formatDay(d.date!)),
                  ),
                ),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(d.timeOfDay == null
                        ? 'Pick time'
                        : formatTime(DateTime(2000, 1, 1, d.timeOfDay! ~/ 60, d.timeOfDay! % 60))),
                  ),
                ),
              ]),
              if (dateError != null) _ErrorText(dateError),
              const SizedBox(height: Gap.m),
              SegmentedButton<TripRepeat>(
                segments: [for (final r in TripRepeat.values) ButtonSegment(value: r, label: Text(r.label))],
                selected: {d.repeat},
                onSelectionChanged: (s) => setState(() => d.repeat = s.first),
              ),
              if (d.repeat == TripRepeat.weekdays) ...[
                const SizedBox(height: Gap.s),
                Wrap(spacing: Gap.s, children: [
                  for (var i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(weekdayNames[i - 1]),
                      selected: d.weekdays.contains(i),
                      onSelected: (on) => setState(() => on ? d.weekdays.add(i) : d.weekdays.remove(i)),
                    ),
                ]),
                if (dayError != null) _ErrorText(dayError),
              ],

              const SectionTitle('Vehicle'),
              SegmentedButton<VehicleType>(
                segments: const [
                  ButtonSegment(value: VehicleType.car, label: Text('Car'), icon: Icon(Icons.directions_car)),
                  ButtonSegment(value: VehicleType.bike, label: Text('Bike'), icon: Icon(Icons.two_wheeler)),
                ],
                selected: {d.vehicleType},
                onSelectionChanged: (s) => _setVehicle(s.first),
              ),
              const SizedBox(height: Gap.m),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_seat_outlined),
                  title: const Text('Seats for riders'),
                  subtitle: Text('Max ${d.vehicleType.maxSeats} for a ${d.vehicleType.label.toLowerCase()}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton.filledTonal(
                      onPressed: d.seats > 1 ? () => setState(() => d.seats--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                      child: Text('${d.seats}', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton.filledTonal(
                      onPressed: d.seats < d.vehicleType.maxSeats ? () => setState(() => d.seats++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Number plate', hintText: 'e.g. LEA-1234', prefixIcon: Icon(Icons.pin_outlined)),
                validator: (v) => TripValidator.plate(v ?? ''),
              ),

              const SectionTitle('Price'),
              SegmentedButton<PricingMode>(
                segments: [for (final p in PricingMode.values) ButtonSegment(value: p, label: Text(p.label))],
                selected: {d.pricingMode},
                onSelectionChanged: (s) => setState(() => d.pricingMode = s.first),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: d.pricingMode == PricingMode.totalSplit ? 'Total trip price (Rs)' : 'Price per seat (Rs)',
                  prefixText: 'Rs ',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isNotEmpty && int.tryParse(text) == null) return 'Whole rupees only, e.g. 1500.';
                  return TripValidator.price(d.pricingMode, int.tryParse(text));
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Gap.s),
              _PriceExample(mode: d.pricingMode, price: int.tryParse(_price.text.trim()), seats: d.seats),
              const SizedBox(height: Gap.l),
              BusyButton(label: 'Post trip', icon: Icons.check, onPressed: _submit),
              const SizedBox(height: Gap.s),
              Text('Free plan: up to ${TripLimitRule.maxTripsPerDay} trips per day.',
                  textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Gap.xs, left: Gap.m),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
      );
}

/// Shows what riders will pay, so the driver understands the pricing mode.
class _PriceExample extends StatelessWidget {
  const _PriceExample({required this.mode, required this.price, required this.seats});
  final PricingMode mode;
  final int? price;
  final int seats;

  @override
  Widget build(BuildContext context) {
    final p = price ?? (mode == PricingMode.totalSplit ? 1500 : 400);
    final lines = mode == PricingMode.perSeat
        ? ['Each rider pays ${rs(p)}.']
        : [
            'Shared by riders + you, rounded up:',
            for (var n = 1; n <= seats; n++)
              '$n rider${n == 1 ? '' : 's'} → ${rs(CostSplit.riderShare(mode: mode, price: p, riderCount: n))} each',
          ];
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(price == null ? 'Example' : 'What riders pay',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final l in lines) Text(l),
          ],
        ),
      ),
    );
  }
}
