// All money and business rules for Carp, as plain Dart (no UI code).
// Every rupee amount is a whole number (int) and is always rounded UP.

import 'models.dart';

/// Result of checking a rule: either ok, or not ok with a friendly message.
class RuleResult {
  const RuleResult.ok() : ok = true, message = '';
  const RuleResult.fail(this.message) : ok = false;

  final bool ok;
  final String message;
}

/// Basic rupee math.
class Money {
  /// Divide and round UP, e.g. ceilDiv(1000, 3) = 334.
  static int ceilDiv(int amount, int parts) {
    if (parts <= 0) throw ArgumentError('parts must be > 0');
    if (amount <= 0) return 0;
    return (amount + parts - 1) ~/ parts;
  }

  /// A percentage of an amount, rounded UP, e.g. 10% of 334 = 34.
  static int percentUp(int amount, int percent) => ceilDiv(amount * percent, 100);
}

/// How much one rider pays for a trip.
class CostSplit {
  /// Share per rider when [riderCount] riders take part.
  /// Total split: the total is shared by the riders PLUS the driver.
  /// Per seat: every rider pays the fixed seat price.
  static int riderShare({
    required PricingMode mode,
    required int price,
    required int riderCount,
  }) {
    if (riderCount <= 0) return 0;
    return switch (mode) {
      PricingMode.totalSplit => Money.ceilDiv(price, riderCount + 1),
      PricingMode.perSeat => price,
    };
  }

  /// Charges after the driver confirms attendance: only PRESENT riders pay.
  /// Returns riderId -> amount. Zero attendees = empty map (no charges).
  static Map<String, int> chargesFor({
    required PricingMode mode,
    required int price,
    required List<String> presentRiderIds,
  }) {
    final share = riderShare(
      mode: mode,
      price: price,
      riderCount: presentRiderIds.length,
    );
    return {for (final id in presentRiderIds) id: share};
  }
}

/// Free plan: at most 2 trips per driver per calendar day.
class TripLimitRule {
  static const maxTripsPerDay = 2;
  static const limitMessage = 'Free plan allows 2 trips per day. Pro coming soon.';

  /// [postedAt] = times of the driver's earlier posts (cancelled ones count too).
  static RuleResult canPost({required List<DateTime> postedAt, required DateTime now}) {
    final today = postedAt.where((t) => _sameDay(t, now)).length;
    return today >= maxTripsPerDay
        ? const RuleResult.fail(limitMessage)
        : const RuleResult.ok();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Can a rider join a trip?
class SeatRule {
  static RuleResult canJoin({
    required int seats,
    required int joinedCount,
    required bool alreadyJoined,
    required bool isDriver,
    required bool isOpen,
  }) {
    if (isDriver) return const RuleResult.fail('You cannot join your own trip.');
    if (!isOpen) return const RuleResult.fail('This trip is no longer open.');
    if (alreadyJoined) return const RuleResult.fail('You already joined this trip.');
    if (joinedCount >= seats) return const RuleResult.fail('Sorry, this trip is full.');
    return const RuleResult.ok();
  }
}

/// Cancellation penalties (10%).
class CancellationRule {
  static const freeWindow = Duration(minutes: 10);
  static const penaltyPercent = 10;

  /// Penalty a rider pays when cancelling. Free within 10 minutes of joining.
  static int riderPenalty({
    required DateTime joinedAt,
    required DateTime now,
    required int share,
  }) {
    final waited = now.difference(joinedAt);
    if (waited <= freeWindow) return 0;
    return Money.percentUp(share, penaltyPercent);
  }

  /// When the driver cancels: each joined rider gets 10% of their share as
  /// credit from the driver. Input and output: riderId -> amount.
  static Map<String, int> driverCancelCredits(Map<String, int> sharesByRider) => {
        for (final e in sharesByRider.entries)
          e.key: Money.percentUp(e.value, penaltyPercent),
      };
}

/// One ledger line the repository should add when attendance is edited.
class LedgerAdjustment {
  const LedgerAdjustment(this.riderId, this.type, this.amount);
  final String riderId;
  final LedgerType type;
  final int amount;

  @override
  String toString() => '$riderId ${type.name} $amount';
}

/// Attendance can be edited for 24 hours after confirming the trip.
class AttendanceRule {
  static const editWindow = Duration(hours: 24);

  static RuleResult canEdit({required DateTime confirmedAt, required DateTime now}) {
    return now.difference(confirmedAt) <= editWindow
        ? const RuleResult.ok()
        : const RuleResult.fail('Attendance can only be edited within 24 hours of confirming.');
  }

  /// Never overwrite old entries: for every rider whose charge changed,
  /// add a reversal of the old charge and a new charge.
  static List<LedgerAdjustment> planEdit({
    required Map<String, int> oldCharges,
    required Map<String, int> newCharges,
  }) {
    final result = <LedgerAdjustment>[];
    final riders = {...oldCharges.keys, ...newCharges.keys};
    for (final id in riders) {
      final oldAmount = oldCharges[id] ?? 0;
      final newAmount = newCharges[id] ?? 0;
      if (oldAmount == newAmount) continue;
      if (oldAmount > 0) result.add(LedgerAdjustment(id, LedgerType.reversal, -oldAmount));
      if (newAmount > 0) result.add(LedgerAdjustment(id, LedgerType.charge, newAmount));
    }
    return result;
  }
}

/// Riders may dispute a charge or penalty within 24 hours (demo only).
class DisputeRule {
  static const window = Duration(hours: 24);

  static RuleResult canDispute({
    required LedgerType type,
    required DateTime chargedAt,
    required DateTime now,
    required bool alreadyDisputed,
  }) {
    if (type != LedgerType.charge && type != LedgerType.penalty) {
      return const RuleResult.fail('Only charges and penalties can be disputed.');
    }
    if (alreadyDisputed) return const RuleResult.fail('You already disputed this charge.');
    if (now.difference(chargedAt) > window) {
      return const RuleResult.fail('Disputes are only allowed within 24 hours.');
    }
    return const RuleResult.ok();
  }
}

/// Stops the same payment from being added twice (e.g. a double tap).
class PaymentGuard {
  static const window = Duration(seconds: 10);

  static RuleResult check({
    required List<Payment> existing,
    required String riderId,
    required String driverId,
    required int amount,
    required PaymentMethod method,
    required DateTime now,
  }) {
    if (amount <= 0) return const RuleResult.fail('Amount must be more than Rs 0.');
    final duplicate = existing.any((p) =>
        p.riderId == riderId &&
        p.driverId == driverId &&
        p.amount == amount &&
        p.method == method &&
        p.status != PaymentStatus.rejected &&
        now.difference(p.createdAt).abs() <= window);
    return duplicate
        ? const RuleResult.fail('This payment was already added.')
        : const RuleResult.ok();
  }
}

/// Balance from ledger entries. Positive = owes, negative = credit.
class Balance {
  static int of(Iterable<LedgerEntry> entries) =>
      entries.fold(0, (sum, e) => sum + e.amount);
}
