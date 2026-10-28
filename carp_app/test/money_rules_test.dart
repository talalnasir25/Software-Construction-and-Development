import 'package:carp_app/domain/models.dart';
import 'package:carp_app/domain/money_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 29, 8, 0);

  group('Cost split (total split shares with the driver)', () {
    int split(int total, int riders) =>
        CostSplit.riderShare(mode: PricingMode.totalSplit, price: total, riderCount: riders);

    test('Rs 1500 with 1 rider = Rs 750 each', () => expect(split(1500, 1), 750));
    test('Rs 1500 with 2 riders = Rs 500 each', () => expect(split(1500, 2), 500));
    test('Rs 1500 with 3 riders = Rs 375 each', () => expect(split(1500, 3), 375));
    test('fraction rounds UP: Rs 1000 / 3 people = Rs 334', () => expect(split(1000, 2), 334));
    test('fraction rounds UP: Rs 1000 / 4 people = Rs 250 (exact)', () => expect(split(1000, 3), 250));
    test('wrong answer is not accepted: Rs 1000 / 3 is not 333', () => expect(split(1000, 2), isNot(333)));
  });

  group('Per seat pricing', () {
    test('each rider pays the seat price regardless of count', () {
      for (final riders in [1, 2, 4]) {
        expect(
          CostSplit.riderShare(mode: PricingMode.perSeat, price: 400, riderCount: riders),
          400,
        );
      }
    });

    test('charges only present riders', () {
      final charges = CostSplit.chargesFor(
        mode: PricingMode.perSeat,
        price: 400,
        presentRiderIds: ['a', 'b'],
      );
      expect(charges, {'a': 400, 'b': 400});
    });
  });

  group('Zero attendees', () {
    test('no charges for total split', () {
      expect(
        CostSplit.chargesFor(mode: PricingMode.totalSplit, price: 1500, presentRiderIds: []),
        isEmpty,
      );
    });
    test('no charges for per seat', () {
      expect(
        CostSplit.chargesFor(mode: PricingMode.perSeat, price: 400, presentRiderIds: []),
        isEmpty,
      );
    });
  });

  group('Rounding helpers', () {
    test('ceilDiv rounds up', () => expect(Money.ceilDiv(1001, 2), 501));
    test('10% of 334 rounds up to 34', () => expect(Money.percentUp(334, 10), 34));
    test('10% of 750 = 75', () => expect(Money.percentUp(750, 10), 75));
  });

  group('2 trips per day limit', () {
    test('1st and 2nd trip of the day allowed', () {
      expect(TripLimitRule.canPost(postedAt: [], now: t0).ok, isTrue);
      expect(TripLimitRule.canPost(postedAt: [t0], now: t0).ok, isTrue);
    });

    test('3rd trip on the same day rejected with friendly message', () {
      final r = TripLimitRule.canPost(
        postedAt: [t0.subtract(const Duration(hours: 1)), t0],
        now: t0.add(const Duration(hours: 5)),
      );
      expect(r.ok, isFalse);
      expect(r.message, 'Free plan allows 2 trips per day. Pro coming soon.');
    });

    test('trips from yesterday do not count', () {
      final yesterday = t0.subtract(const Duration(days: 1));
      expect(TripLimitRule.canPost(postedAt: [yesterday, yesterday], now: t0).ok, isTrue);
    });
  });

  group('Seat check', () {
    RuleResult join({int seats = 4, int joined = 0, bool already = false, bool driver = false, bool open = true}) =>
        SeatRule.canJoin(
          seats: seats,
          joinedCount: joined,
          alreadyJoined: already,
          isDriver: driver,
          isOpen: open,
        );

    test('join allowed with free seats', () => expect(join(seats: 4, joined: 3).ok, isTrue));
    test('full trip rejected', () {
      final r = join(seats: 1, joined: 1);
      expect(r.ok, isFalse);
      expect(r.message, contains('full'));
    });
    test('cannot join twice', () => expect(join(already: true).ok, isFalse));
    test('driver cannot join own trip', () => expect(join(driver: true).ok, isFalse));
    test('cannot join cancelled/confirmed trip', () => expect(join(open: false).ok, isFalse));
  });

  group('Rider cancellation (10-minute rule)', () {
    test('cancel at 9 minutes is free', () {
      expect(
        CancellationRule.riderPenalty(
          joinedAt: t0,
          now: t0.add(const Duration(minutes: 9)),
          share: 750,
        ),
        0,
      );
    });

    test('cancel at exactly 10 minutes is still free', () {
      expect(
        CancellationRule.riderPenalty(joinedAt: t0, now: t0.add(const Duration(minutes: 10)), share: 750),
        0,
      );
    });

    test('cancel at 11 minutes = 10% penalty', () {
      expect(
        CancellationRule.riderPenalty(
          joinedAt: t0,
          now: t0.add(const Duration(minutes: 11)),
          share: 750,
        ),
        75,
      );
    });

    test('penalty rounds UP (10% of 334 = 34)', () {
      expect(
        CancellationRule.riderPenalty(joinedAt: t0, now: t0.add(const Duration(hours: 1)), share: 334),
        34,
      );
    });
  });

  group('Driver cancellation credits', () {
    test('each joined rider gets 10% of their share', () {
      // Rs 1500 total split, 2 riders => share 500 each => credit 50 each.
      final share = CostSplit.riderShare(mode: PricingMode.totalSplit, price: 1500, riderCount: 2);
      expect(CancellationRule.driverCancelCredits({'a': share, 'b': share}), {'a': 50, 'b': 50});
    });

    test('credit rounds UP', () {
      expect(CancellationRule.driverCancelCredits({'a': 334}), {'a': 34});
    });

    test('no riders = no credits', () {
      expect(CancellationRule.driverCancelCredits({}), isEmpty);
    });
  });

  group('Attendance edit window (24h)', () {
    test('edit at 23h allowed', () {
      expect(AttendanceRule.canEdit(confirmedAt: t0, now: t0.add(const Duration(hours: 23))).ok, isTrue);
    });

    test('edit at 25h rejected', () {
      final r = AttendanceRule.canEdit(confirmedAt: t0, now: t0.add(const Duration(hours: 25)));
      expect(r.ok, isFalse);
      expect(r.message, contains('24 hours'));
    });

    test('edit adds reversal + new charges, never overwrites', () {
      // Confirmed with 1 rider present (750). Edit: 2 riders present (500 each).
      final plan = AttendanceRule.planEdit(
        oldCharges: {'a': 750},
        newCharges: {'a': 500, 'b': 500},
      );
      expect(plan.map((e) => e.toString()), [
        'a reversal -750',
        'a charge 500',
        'b charge 500',
      ]);
      // Net effect: a pays 500, b pays 500.
      final net = plan.fold<int>(750, (s, e) => s + e.amount);
      expect(net, 1000);
    });

    test('marking everyone absent reverses all charges', () {
      final plan = AttendanceRule.planEdit(oldCharges: {'a': 400}, newCharges: {});
      expect(plan.single.type, LedgerType.reversal);
      expect(plan.single.amount, -400);
    });

    test('unchanged riders get no new entries', () {
      expect(AttendanceRule.planEdit(oldCharges: {'a': 400}, newCharges: {'a': 400}), isEmpty);
    });
  });

  group('Disputes (24h)', () {
    test('charge disputed within 24h allowed', () {
      expect(
        DisputeRule.canDispute(
          type: LedgerType.charge,
          chargedAt: t0,
          now: t0.add(const Duration(hours: 2)),
          alreadyDisputed: false,
        ).ok,
        isTrue,
      );
    });
    test('dispute after 24h rejected', () {
      expect(
        DisputeRule.canDispute(
          type: LedgerType.charge,
          chargedAt: t0,
          now: t0.add(const Duration(hours: 25)),
          alreadyDisputed: false,
        ).ok,
        isFalse,
      );
    });
  });

  group('Payment duplicate check', () {
    Payment existing() => Payment(
          id: 'p1',
          riderId: 'r',
          driverId: 'd',
          amount: 500,
          method: PaymentMethod.jazzCash,
          createdAt: t0,
        );

    RuleResult check({int amount = 500, PaymentMethod method = PaymentMethod.jazzCash, Duration after = const Duration(seconds: 2)}) =>
        PaymentGuard.check(
          existing: [existing()],
          riderId: 'r',
          driverId: 'd',
          amount: amount,
          method: method,
          now: t0.add(after),
        );

    test('duplicate payment (double tap) rejected', () {
      final r = check();
      expect(r.ok, isFalse);
      expect(r.message, 'This payment was already added.');
    });
    test('different amount allowed', () => expect(check(amount: 300).ok, isTrue));
    test('different method allowed', () => expect(check(method: PaymentMethod.cash).ok, isTrue));
    test('same payment much later allowed', () => expect(check(after: const Duration(minutes: 5)).ok, isTrue));
    test('zero amount rejected', () => expect(check(amount: 0).ok, isFalse));
  });

  group('Balance and overpayment', () {
    LedgerEntry e(int amount, LedgerType type) => LedgerEntry(
          id: '$amount',
          riderId: 'r',
          driverId: 'd',
          type: type,
          amount: amount,
          note: '',
          createdAt: t0,
        );

    test('charge minus payment = owes', () {
      expect(Balance.of([e(750, LedgerType.charge), e(-500, LedgerType.payment)]), 250);
    });
    test('overpayment becomes credit (negative)', () {
      expect(Balance.of([e(500, LedgerType.charge), e(-700, LedgerType.payment)]), -200);
    });
  });
}
