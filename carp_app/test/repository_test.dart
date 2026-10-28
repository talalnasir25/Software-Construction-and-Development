import 'package:carp_app/data/carp_repository.dart';
import 'package:carp_app/data/in_memory_repository.dart';
import 'package:carp_app/domain/models.dart';
import 'package:carp_app/domain/trip_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end checks of the in-memory repository with a fake clock.
void main() {
  late DateTime now;
  late InMemoryCarpRepository repo;

  setUp(() {
    now = DateTime(2026, 10, 28, 20, 0);
    repo = InMemoryCarpRepository(clock: () => now, latency: Duration.zero);
  });

  TripDraft draft({PricingMode mode = PricingMode.totalSplit, int price = 1500, int seats = 3}) => TripDraft()
    ..from = 'G-11 Markaz'
    ..to = 'COMSATS'
    ..date = DateTime(2026, 10, 29)
    ..timeOfDay = 8 * 60
    ..seats = seats
    ..plate = 'LEA-1234'
    ..pricingMode = mode
    ..price = price;

  Future<String> sum(String riderId, String driverId) async {
    final m = await repo.riderMoney(riderId);
    return m.parties.where((p) => p.user.id == driverId).map((p) => p.balance).join();
  }

  test('seeded data loads', () async {
    expect(await repo.demoUsers(), hasLength(4));
    expect(await repo.browseTrips('u3'), isNotEmpty);
  });

  test('Ayesha already posted 1 trip today: 2nd allowed, 3rd rejected', () async {
    await repo.postTrip('u1', draft());
    expect(
      () => repo.postTrip('u1', draft()),
      throwsA(isA<CarpException>().having((e) => e.message, 'message', contains('2 trips per day'))),
    );
  });

  test('invalid draft rejected with clear message', () async {
    expect(
      () => repo.postTrip('u2', draft()..seats = 2..vehicleType = VehicleType.bike),
      throwsA(isA<CarpException>().having((e) => e.message, 'message', contains('at most 1 seat'))),
    );
  });

  test('joining a full trip is rejected', () async {
    // t2 is Bilal's bike trip, already full with Usman.
    expect(
      () => repo.joinTrip('t2', 'u3'),
      throwsA(isA<CarpException>().having((e) => e.message, 'message', contains('full'))),
    );
  });

  test('full flow: post, join, confirm with one absent, then edit attendance', () async {
    final trip = await repo.postTrip('u2', draft(seats: 1)..vehicleType = VehicleType.bike);
    await repo.joinTrip(trip.id, 'u3');
    await repo.confirmTrip(trip.id, {'u3'});
    // Bike, 1 rider + driver: 1500 / 2 = 750.
    expect(await sum('u3', 'u2'), '725'); // 750 charge - 25 seeded credit

    now = now.add(const Duration(hours: 23));
    await repo.editAttendance(trip.id, {}); // mark absent
    final v = await repo.tripDetails(trip.id);
    expect(v.trip.isEdited, isTrue);
    expect(v.entries.map((e) => e.entry.type), containsAll([LedgerType.charge, LedgerType.reversal]));
    expect(await sum('u3', 'u2'), '-25');
  });

  test('editing attendance after 25h is rejected', () async {
    final trip = await repo.postTrip('u2', draft(seats: 1)..vehicleType = VehicleType.bike);
    await repo.joinTrip(trip.id, 'u3');
    await repo.confirmTrip(trip.id, {'u3'});
    now = now.add(const Duration(hours: 25));
    expect(() => repo.editAttendance(trip.id, {}), throwsA(isA<CarpException>()));
  });

  test('rider cancel: free at 9 min, penalty at 11 min', () async {
    final trip = await repo.postTrip('u2', draft(mode: PricingMode.perSeat, price: 400, seats: 1)
      ..vehicleType = VehicleType.bike);
    await repo.joinTrip(trip.id, 'u3');
    now = now.add(const Duration(minutes: 9));
    expect(await repo.cancelBooking(trip.id, 'u3'), 0);

    await repo.joinTrip(trip.id, 'u3');
    now = now.add(const Duration(minutes: 11));
    expect(await repo.cancelBooking(trip.id, 'u3'), 40);
  });

  test('driver cancel gives each rider 10% credit', () async {
    // t1: Rs 1500 total split, Sara + Usman joined => share 500 => credit 50.
    await repo.cancelTrip('t1', 'u1');
    final v = await repo.tripDetails('t1');
    expect(v.entries.map((e) => e.entry.amount), [-50, -50]);
  });

  test('zero attendees creates no charges', () async {
    await repo.confirmTrip('t1', {});
    expect((await repo.tripDetails('t1')).entries, isEmpty);
  });

  test('double tap payment is rejected; overpayment becomes credit', () async {
    // Sara owes Ayesha 600 (seeded).
    await repo.recordPayment(riderId: 'u3', driverId: 'u1', amount: 700, method: PaymentMethod.cash);
    expect(
      () => repo.recordPayment(riderId: 'u3', driverId: 'u1', amount: 700, method: PaymentMethod.cash),
      throwsA(isA<CarpException>().having((e) => e.message, 'message', 'This payment was already added.')),
    );
    expect(await sum('u3', 'u1'), '-100');
  });

  test('rider "I paid" stays pending until the driver confirms', () async {
    await repo.markPaid(riderId: 'u3', driverId: 'u1', amount: 600, method: PaymentMethod.easypaisa);
    expect(await sum('u3', 'u1'), '600');
    final pending = (await repo.driverMoney('u1')).pending.firstWhere((p) => p.rider.id == 'u3');
    await repo.confirmPayment(pending.payment.id);
    expect(await sum('u3', 'u1'), '0');
  });

  test('dispute within 24h is listed on the trip', () async {
    final charge = (await repo.tripDetails('t4')).entries.first;
    await repo.disputeCharge(charge.entry.id, 'u3', 'I was late but present');
    expect((await repo.tripDetails('t4')).disputes, hasLength(1));
  });
}
