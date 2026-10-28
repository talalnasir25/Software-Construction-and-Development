// Demo data source: everything lives in memory and resets on page reload.
// All business rules come from domain/money_rules.dart.

import '../domain/models.dart';
import '../domain/money_rules.dart';
import '../domain/trip_draft.dart';
import 'carp_repository.dart';

class InMemoryCarpRepository extends CarpRepository {
  InMemoryCarpRepository({
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 350),
    bool seed = true,
  }) : _clock = clock ?? DateTime.now {
    if (seed) _seed();
  }

  final DateTime Function() _clock;

  /// Fake network delay so loading states are visible in the demo.
  final Duration latency;

  final _users = <AppUser>[];
  final _trips = <Trip>[];
  final _bookings = <Booking>[];
  final _entries = <LedgerEntry>[];
  final _payments = <Payment>[];
  final _disputes = <Dispute>[];
  int _nextId = 1;

  DateTime get _now => _clock();
  String _id(String prefix) => '$prefix${_nextId++}';
  Future<void> _wait() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  AppUser _user(String id) => _users.firstWhere((u) => u.id == id);

  Trip _trip(String id) => _trips.firstWhere(
        (t) => t.id == id,
        orElse: () => throw CarpException('Trip not found.'),
      );

  List<Booking> _joined(String tripId) => _bookings
      .where((b) => b.tripId == tripId && b.status == BookingStatus.joined)
      .toList();

  void _addEntry(Trip? trip, String riderId, String driverId, LedgerType type, int amount, String note,
      [DateTime? at]) {
    _entries.add(LedgerEntry(
      id: _id('e'),
      tripId: trip?.id,
      riderId: riderId,
      driverId: driverId,
      type: type,
      amount: amount,
      note: note,
      createdAt: at ?? _now,
    ));
  }

  EntryView _entryView(LedgerEntry e) => EntryView(
        e,
        _user(e.riderId),
        _user(e.driverId),
        disputed: _disputes.any((d) => d.entryId == e.id),
      );

  TripView _view(Trip t) {
    final entries = _entries.where((e) => e.tripId == t.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return TripView(
      trip: t,
      driver: _user(t.driverId),
      riders: [for (final b in _joined(t.id)) BookingView(b, _user(b.riderId))],
      entries: entries.map(_entryView).toList(),
      disputes: [
        for (final d in _disputes.where((d) => d.tripId == t.id))
          DisputeView(d, _user(d.riderId), _entries.firstWhere((e) => e.id == d.entryId)),
      ],
    );
  }

  // ---------------- Users ----------------

  @override
  Future<AppUser> login(String email, String password) async {
    await _wait();
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty || !clean.contains('@')) throw CarpException('Please enter a valid email.');
    if (password.isEmpty) throw CarpException('Please enter a password.');

    // DEMO ONLY: any email and password works.
    // Real login will only allow emails ending in "@isbstudent.comsats.edu.pk"
    // (students and faculty) and will be verified on the server.
    for (final u in _users) {
      if (u.email == clean) return u;
    }
    final name = clean
        .split('@')
        .first
        .split(RegExp(r'[._-]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
    final user = AppUser(id: _id('u'), name: name.isEmpty ? 'New Student' : name, email: clean);
    _users.add(user);
    notifyListeners();
    return user;
  }

  @override
  Future<List<AppUser>> demoUsers() async {
    await _wait();
    return _users.take(4).toList();
  }

  @override
  Future<void> updateProfile(AppUser user) async {
    await _wait();
    if (user.name.trim().isEmpty) throw CarpException('Name cannot be empty.');
    notifyListeners(); // user object is already shared; just refresh screens
  }

  // ---------------- Trips ----------------

  @override
  Future<List<TripView>> browseTrips(String riderId) async {
    await _wait();
    return _trips
        .where((t) => t.status == TripStatus.open && t.driverId != riderId && t.departure.isAfter(_now))
        .map(_view)
        .toList()
      ..sort((a, b) => a.trip.departure.compareTo(b.trip.departure));
  }

  @override
  Future<List<TripView>> ridesOf(String riderId) async {
    await _wait();
    final ids = _bookings
        .where((b) => b.riderId == riderId && b.status == BookingStatus.joined)
        .map((b) => b.tripId)
        .toSet();
    return _trips.where((t) => ids.contains(t.id)).map(_view).toList()
      ..sort((a, b) => b.trip.departure.compareTo(a.trip.departure));
  }

  @override
  Future<List<TripView>> tripsOfDriver(String driverId) async {
    await _wait();
    return _trips.where((t) => t.driverId == driverId).map(_view).toList()
      ..sort((a, b) => b.trip.departure.compareTo(a.trip.departure));
  }

  @override
  Future<TripView> tripDetails(String tripId) async {
    await _wait();
    return _view(_trip(tripId));
  }

  @override
  Future<Trip> postTrip(String driverId, TripDraft draft) async {
    await _wait();
    final errors = TripValidator.validate(draft, _now);
    if (errors.isNotEmpty) throw CarpException(errors.first);

    final limit = TripLimitRule.canPost(
      postedAt: _trips.where((t) => t.driverId == driverId).map((t) => t.createdAt).toList(),
      now: _now,
    );
    if (!limit.ok) throw CarpException(limit.message);

    final trip = Trip(
      id: _id('t'),
      driverId: driverId,
      from: draft.from.trim(),
      to: draft.to.trim(),
      departure: draft.departure!,
      repeat: draft.repeat,
      weekdays: draft.repeat == TripRepeat.weekdays ? {...draft.weekdays} : {},
      vehicleType: draft.vehicleType,
      seats: draft.seats,
      plate: draft.plate.trim().toUpperCase(),
      pricingMode: draft.pricingMode,
      price: draft.price!,
      createdAt: _now,
    );
    _trips.add(trip);

    // Remember vehicle info on the profile for next time.
    final driver = _user(driverId);
    driver.vehicleType = draft.vehicleType;
    driver.plate = trip.plate;
    notifyListeners();
    return trip;
  }

  @override
  Future<void> joinTrip(String tripId, String riderId) async {
    await _wait();
    final trip = _trip(tripId);
    final joined = _joined(tripId);
    final check = SeatRule.canJoin(
      seats: trip.seats,
      joinedCount: joined.length,
      alreadyJoined: joined.any((b) => b.riderId == riderId),
      isDriver: trip.driverId == riderId,
      isOpen: trip.status == TripStatus.open,
    );
    if (!check.ok) throw CarpException(check.message);
    _bookings.add(Booking(id: _id('b'), tripId: tripId, riderId: riderId, joinedAt: _now));
    notifyListeners();
  }

  @override
  Future<int> cancelBooking(String tripId, String riderId) async {
    await _wait();
    final trip = _trip(tripId);
    if (trip.status != TripStatus.open) throw CarpException('This trip can no longer be cancelled.');
    final booking = _joined(tripId).where((b) => b.riderId == riderId).firstOrNull;
    if (booking == null) throw CarpException('You are not on this trip.');

    final share = _view(trip).currentShare;
    final penalty = CancellationRule.riderPenalty(joinedAt: booking.joinedAt, now: _now, share: share);
    if (penalty > 0) {
      _addEntry(trip, riderId, trip.driverId, LedgerType.penalty, penalty,
          'Late cancellation: 10% of Rs $share');
    }
    booking.status = BookingStatus.cancelled;
    notifyListeners();
    return penalty;
  }

  @override
  Future<void> cancelTrip(String tripId, String driverId) async {
    await _wait();
    final trip = _trip(tripId);
    if (trip.driverId != driverId) throw CarpException('Only the driver can cancel this trip.');
    if (trip.status != TripStatus.open) throw CarpException('This trip can no longer be cancelled.');

    final share = _view(trip).currentShare;
    final credits = CancellationRule.driverCancelCredits({
      for (final b in _joined(tripId)) b.riderId: share,
    });
    credits.forEach((riderId, credit) {
      _addEntry(trip, riderId, driverId, LedgerType.credit, -credit,
          'Driver cancelled: 10% of Rs $share');
    });
    trip.status = TripStatus.cancelled;
    notifyListeners();
  }

  // ---------------- Attendance ----------------

  @override
  Future<void> confirmTrip(String tripId, Set<String> presentRiderIds) async {
    await _wait();
    final trip = _trip(tripId);
    if (trip.status != TripStatus.open) throw CarpException('This trip is already ${trip.status.name}.');
    final joined = _joined(tripId);
    for (final b in joined) {
      b.present = presentRiderIds.contains(b.riderId);
    }
    final charges = CostSplit.chargesFor(
      mode: trip.pricingMode,
      price: trip.price,
      presentRiderIds: [for (final b in joined) if (b.present) b.riderId],
    );
    charges.forEach((riderId, amount) {
      _addEntry(trip, riderId, trip.driverId, LedgerType.charge, amount, 'Trip ${trip.from} → ${trip.to}');
    });
    trip.status = TripStatus.confirmed;
    trip.confirmedAt = _now;
    notifyListeners();
  }

  @override
  Future<void> editAttendance(String tripId, Set<String> presentRiderIds) async {
    await _wait();
    final trip = _trip(tripId);
    if (trip.status != TripStatus.confirmed) throw CarpException('Confirm the trip first.');
    final allowed = AttendanceRule.canEdit(confirmedAt: trip.confirmedAt!, now: _now);
    if (!allowed.ok) throw CarpException(allowed.message);

    final joined = _joined(tripId);
    final changed = joined.where((b) => b.present != presentRiderIds.contains(b.riderId)).toList();
    if (changed.isEmpty) throw CarpException('Nothing changed.');

    // Current charge per rider = all charges + reversals for this trip.
    final oldCharges = <String, int>{};
    for (final e in _entries.where((e) => e.tripId == tripId)) {
      if (e.type == LedgerType.charge || e.type == LedgerType.reversal) {
        oldCharges[e.riderId] = (oldCharges[e.riderId] ?? 0) + e.amount;
      }
    }
    oldCharges.removeWhere((_, v) => v == 0);
    final newCharges = CostSplit.chargesFor(
      mode: trip.pricingMode,
      price: trip.price,
      presentRiderIds: [for (final b in joined) if (presentRiderIds.contains(b.riderId)) b.riderId],
    );
    for (final a in AttendanceRule.planEdit(oldCharges: oldCharges, newCharges: newCharges)) {
      final note = a.type == LedgerType.reversal ? 'Attendance edited: old charge reversed' : 'Attendance edited: new charge';
      _addEntry(trip, a.riderId, trip.driverId, a.type, a.amount, note);
    }

    final summary = changed
        .map((b) => '${_user(b.riderId).name}: ${b.present ? 'present → absent' : 'absent → present'}')
        .join(', ');
    for (final b in joined) {
      b.present = presentRiderIds.contains(b.riderId);
    }
    trip.editHistory.add(TripEdit(at: _now, summary: summary));
    notifyListeners();
  }

  @override
  Future<void> disputeCharge(String entryId, String riderId, String reason) async {
    await _wait();
    final entry = _entries.firstWhere((e) => e.id == entryId,
        orElse: () => throw CarpException('Charge not found.'));
    if (entry.riderId != riderId) throw CarpException('You can only dispute your own charges.');
    if (reason.trim().isEmpty) throw CarpException('Please write a short reason.');
    final check = DisputeRule.canDispute(
      type: entry.type,
      chargedAt: entry.createdAt,
      now: _now,
      alreadyDisputed: _disputes.any((d) => d.entryId == entryId),
    );
    if (!check.ok) throw CarpException(check.message);
    _disputes.add(Dispute(
      id: _id('d'),
      tripId: entry.tripId ?? '',
      riderId: riderId,
      entryId: entryId,
      reason: reason.trim(),
      createdAt: _now,
    ));
    notifyListeners();
  }

  // ---------------- Money ----------------

  MoneySummary _summary(bool Function(LedgerEntry) entryFilter, bool Function(Payment) paymentFilter,
      String Function(LedgerEntry) otherParty) {
    final entries = _entries.where(entryFilter).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final byParty = <String, int>{};
    for (final e in entries) {
      byParty[otherParty(e)] = (byParty[otherParty(e)] ?? 0) + e.amount;
    }
    final payments = _payments.where(paymentFilter).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return MoneySummary(
      total: Balance.of(entries),
      parties: [for (final p in byParty.entries) PartyBalance(_user(p.key), p.value)]
        ..sort((a, b) => b.balance.compareTo(a.balance)),
      entries: entries.map(_entryView).toList(),
      payments: [for (final p in payments) PaymentView(p, _user(p.riderId), _user(p.driverId))],
    );
  }

  @override
  Future<MoneySummary> riderMoney(String riderId) async {
    await _wait();
    return _summary((e) => e.riderId == riderId, (p) => p.riderId == riderId, (e) => e.driverId);
  }

  @override
  Future<MoneySummary> driverMoney(String driverId) async {
    await _wait();
    return _summary((e) => e.driverId == driverId, (p) => p.driverId == driverId, (e) => e.riderId);
  }

  Payment _newPayment(String riderId, String driverId, int amount, PaymentMethod method) {
    // Checked BEFORE the fake delay too, so a double tap is caught right away.
    final check = PaymentGuard.check(
      existing: _payments,
      riderId: riderId,
      driverId: driverId,
      amount: amount,
      method: method,
      now: _now,
    );
    if (!check.ok) throw CarpException(check.message);
    if (riderId == driverId) throw CarpException('Rider and driver must be different people.');
    final p = Payment(
      id: _id('p'),
      riderId: riderId,
      driverId: driverId,
      amount: amount,
      method: method,
      createdAt: _now,
    );
    _payments.add(p);
    return p;
  }

  void _settle(Payment p) {
    p.status = PaymentStatus.confirmed;
    _addEntry(null, p.riderId, p.driverId, LedgerType.payment, -p.amount, 'Paid via ${p.method.label}');
  }

  @override
  Future<void> markPaid({
    required String riderId,
    required String driverId,
    required int amount,
    required PaymentMethod method,
  }) async {
    _newPayment(riderId, driverId, amount, method); // stays PENDING
    await _wait();
    notifyListeners();
  }

  @override
  Future<void> recordPayment({
    required String riderId,
    required String driverId,
    required int amount,
    required PaymentMethod method,
  }) async {
    final p = _newPayment(riderId, driverId, amount, method);
    _settle(p); // recorded by the driver = confirmed straight away
    await _wait();
    notifyListeners();
  }

  @override
  Future<void> confirmPayment(String paymentId) async {
    await _wait();
    final p = _payments.firstWhere((p) => p.id == paymentId);
    if (p.status != PaymentStatus.pending) throw CarpException('This payment was already handled.');
    _settle(p);
    notifyListeners();
  }

  @override
  Future<void> rejectPayment(String paymentId) async {
    await _wait();
    final p = _payments.firstWhere((p) => p.id == paymentId);
    if (p.status != PaymentStatus.pending) throw CarpException('This payment was already handled.');
    p.status = PaymentStatus.rejected;
    notifyListeners();
  }

  // ---------------- Seed data ----------------

  void _seed() {
    final now = _now;
    DateTime day(int offset, int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day + offset, hour, minute);
    final startOfToday = day(0, 0);
    final earlierToday = now.subtract(const Duration(minutes: 30));

    const domain = '@isbstudent.comsats.edu.pk';
    final ayesha = AppUser(
      id: 'u1',
      name: 'Ayesha Khan',
      email: 'ayesha.khan$domain',
      phone: '0300-1234567',
      vehicleType: VehicleType.car,
      vehicleModel: 'Suzuki Cultus (white)',
      plate: 'LEA-1234',
    );
    final bilal = AppUser(
      id: 'u2',
      name: 'Bilal Ahmed',
      email: 'bilal.ahmed$domain',
      phone: '0312-7654321',
      vehicleType: VehicleType.bike,
      vehicleModel: 'Honda CD 70 (red)',
      plate: 'ICT-21-555',
    );
    final sara = AppUser(id: 'u3', name: 'Sara Malik', email: 'sara.malik$domain', phone: '0333-1112223');
    final usman = AppUser(id: 'u4', name: 'Usman Tariq', email: 'usman.tariq$domain', phone: '0345-9998887');
    _users.addAll([ayesha, bilal, sara, usman]);
    _nextId = 100;

    Trip trip(String id, AppUser driver, String from, String to, DateTime departure,
        {TripRepeat repeat = TripRepeat.oneTime,
        Set<int> weekdays = const {},
        required int seats,
        required PricingMode mode,
        required int price,
        required DateTime created}) {
      final t = Trip(
        id: id,
        driverId: driver.id,
        from: from,
        to: to,
        departure: departure,
        repeat: repeat,
        weekdays: weekdays,
        vehicleType: driver.vehicleType!,
        seats: seats,
        plate: driver.plate,
        pricingMode: mode,
        price: price,
        createdAt: created,
      );
      _trips.add(t);
      return t;
    }

    void book(Trip t, AppUser rider, DateTime joinedAt, {bool present = true}) => _bookings.add(
        Booking(id: _id('b'), tripId: t.id, riderId: rider.id, joinedAt: joinedAt, present: present));

    // Upcoming: Ayesha's daily car trip, 2 of 3 seats taken (total split).
    final t1 = trip('t1', ayesha, 'G-11 Markaz', 'COMSATS Park Road', day(1, 8),
        repeat: TripRepeat.daily, seats: 3, mode: PricingMode.totalSplit, price: 1500, created: day(-2, 20));
    book(t1, sara, now.subtract(const Duration(hours: 3))); // cancelling now = penalty
    book(t1, usman, now.subtract(const Duration(minutes: 4))); // cancelling now = free

    // Upcoming: Bilal's bike trip, already FULL.
    final t2 = trip('t2', bilal, 'Bahria Town Phase 7', 'COMSATS Park Road', day(1, 7, 30),
        repeat: TripRepeat.weekdays, weekdays: {1, 3, 5}, seats: 1, mode: PricingMode.perSeat, price: 250,
        created: day(-1, 21));
    book(t2, usman, now.subtract(const Duration(hours: 1)));

    // Upcoming: Ayesha's per-seat trip with free seats. Posted today (1 of 2 free posts used).
    trip('t3', ayesha, 'F-10 Markaz', 'COMSATS Park Road', day(2, 9),
        seats: 4, mode: PricingMode.perSeat, price: 300,
        created: earlierToday.isBefore(startOfToday) ? startOfToday : earlierToday);

    // Past, confirmed 3 hours ago: attendance still editable. Usman was absent.
    final t4 = trip('t4', ayesha, 'COMSATS Park Road', 'G-11 Markaz', now.subtract(const Duration(hours: 5)),
        seats: 3, mode: PricingMode.totalSplit, price: 1200, created: day(-3, 18));
    book(t4, sara, now.subtract(const Duration(days: 1)));
    book(t4, usman, now.subtract(const Duration(days: 1)), present: false);
    t4.status = TripStatus.confirmed;
    t4.confirmedAt = now.subtract(const Duration(hours: 3));
    _addEntry(t4, sara.id, ayesha.id, LedgerType.charge, 600, 'Trip ${t4.from} → ${t4.to}', t4.confirmedAt);

    // Past, confirmed 3 days ago and already paid in cash.
    final t5 = trip('t5', bilal, 'Saddar, Rawalpindi', 'COMSATS Park Road', day(-3, 8),
        seats: 1, mode: PricingMode.perSeat, price: 200, created: day(-4, 19));
    book(t5, sara, day(-4, 20));
    t5.status = TripStatus.confirmed;
    t5.confirmedAt = day(-3, 9);
    _addEntry(t5, sara.id, bilal.id, LedgerType.charge, 200, 'Trip ${t5.from} → ${t5.to}', t5.confirmedAt);
    final cash = Payment(
        id: _id('p'), riderId: sara.id, driverId: bilal.id, amount: 200, method: PaymentMethod.cash,
        createdAt: day(-3, 17), status: PaymentStatus.confirmed);
    _payments.add(cash);
    _addEntry(null, sara.id, bilal.id, LedgerType.payment, -200, 'Paid via Cash', day(-3, 17));

    // Past, confirmed 2 days ago. Usman says he paid by JazzCash (PENDING).
    final t6 = trip('t6', ayesha, 'I-8 Markaz', 'COMSATS Park Road', day(-2, 8),
        seats: 3, mode: PricingMode.perSeat, price: 350, created: day(-3, 22));
    book(t6, usman, day(-3, 22, 30));
    t6.status = TripStatus.confirmed;
    t6.confirmedAt = day(-2, 9);
    _addEntry(t6, usman.id, ayesha.id, LedgerType.charge, 350, 'Trip ${t6.from} → ${t6.to}', t6.confirmedAt);
    _payments.add(Payment(
        id: _id('p'), riderId: usman.id, driverId: ayesha.id, amount: 350, method: PaymentMethod.jazzCash,
        createdAt: now.subtract(const Duration(hours: 1))));

    // Cancelled by Bilal yesterday: Sara got 10% of Rs 250 = Rs 25 credit.
    final t7 = trip('t7', bilal, 'Blue Area', 'COMSATS Park Road', day(-1, 8),
        seats: 1, mode: PricingMode.perSeat, price: 250, created: day(-2, 19));
    book(t7, sara, day(-2, 20));
    t7.status = TripStatus.cancelled;
    _addEntry(t7, sara.id, bilal.id, LedgerType.credit, -25, 'Driver cancelled: 10% of Rs 250', day(-2, 23));
  }
}
