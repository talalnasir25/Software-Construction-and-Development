// The contract between the app and its data source.
// Tonight: InMemoryCarpRepository. Later: an HTTP repository that talks to the
// Node.js + Express + PostgreSQL (Prisma) backend, with the same methods.

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../domain/money_rules.dart';
import '../domain/trip_draft.dart';

/// Thrown when an action is not allowed. [message] is shown to the user.
class CarpException implements Exception {
  CarpException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BookingView {
  BookingView(this.booking, this.rider);
  final Booking booking;
  final AppUser rider;
}

class EntryView {
  EntryView(this.entry, this.rider, this.driver, {required this.disputed});
  final LedgerEntry entry;
  final AppUser rider;
  final AppUser driver;
  final bool disputed;
}

class DisputeView {
  DisputeView(this.dispute, this.rider, this.entry);
  final Dispute dispute;
  final AppUser rider;
  final LedgerEntry entry;
}

class PaymentView {
  PaymentView(this.payment, this.rider, this.driver);
  final Payment payment;
  final AppUser rider;
  final AppUser driver;
}

/// A trip with everything a screen needs to show it.
class TripView {
  TripView({
    required this.trip,
    required this.driver,
    required this.riders,
    required this.entries,
    required this.disputes,
  });

  final Trip trip;
  final AppUser driver;

  /// Riders who are currently joined (not cancelled).
  final List<BookingView> riders;
  final List<EntryView> entries;
  final List<DisputeView> disputes;

  int get joinedCount => riders.length;
  int get seatsLeft => trip.seats - joinedCount;
  bool get isFull => seatsLeft <= 0;

  /// Per-rider cost right now (used for cancellations).
  int get currentShare => CostSplit.riderShare(
        mode: trip.pricingMode,
        price: trip.price,
        riderCount: joinedCount,
      );

  /// What a new rider would pay if they joined now.
  int get shareIfJoin => CostSplit.riderShare(
        mode: trip.pricingMode,
        price: trip.price,
        riderCount: joinedCount + 1,
      );

  BookingView? bookingOf(String userId) {
    for (final b in riders) {
      if (b.rider.id == userId) return b;
    }
    return null;
  }
}

/// Balance with one other person (driver for a rider, rider for a driver).
class PartyBalance {
  PartyBalance(this.user, this.balance);
  final AppUser user;

  /// Positive = rider owes driver. Negative = rider has credit.
  final int balance;
}

/// Money overview for a rider or a driver.
class MoneySummary {
  MoneySummary({
    required this.total,
    required this.parties,
    required this.entries,
    required this.payments,
  });

  final int total;
  final List<PartyBalance> parties;
  final List<EntryView> entries;
  final List<PaymentView> payments;

  List<PaymentView> get pending =>
      payments.where((p) => p.payment.status == PaymentStatus.pending).toList();
}

abstract class CarpRepository extends ChangeNotifier {
  // Users
  Future<AppUser> login(String email, String password);
  Future<List<AppUser>> demoUsers();
  Future<void> updateProfile(AppUser user);

  // Trips
  Future<List<TripView>> browseTrips(String riderId);
  Future<List<TripView>> ridesOf(String riderId);
  Future<List<TripView>> tripsOfDriver(String driverId);
  Future<TripView> tripDetails(String tripId);
  Future<Trip> postTrip(String driverId, TripDraft draft);
  Future<void> joinTrip(String tripId, String riderId);

  /// Returns the penalty charged (0 if free).
  Future<int> cancelBooking(String tripId, String riderId);
  Future<void> cancelTrip(String tripId, String driverId);

  // Attendance and charges
  Future<void> confirmTrip(String tripId, Set<String> presentRiderIds);
  Future<void> editAttendance(String tripId, Set<String> presentRiderIds);
  Future<void> disputeCharge(String entryId, String riderId, String reason);

  // Money
  Future<MoneySummary> riderMoney(String riderId);
  Future<MoneySummary> driverMoney(String driverId);
  Future<void> markPaid({
    required String riderId,
    required String driverId,
    required int amount,
    required PaymentMethod method,
  });
  Future<void> recordPayment({
    required String riderId,
    required String driverId,
    required int amount,
    required PaymentMethod method,
  });
  Future<void> confirmPayment(String paymentId);
  Future<void> rejectPayment(String paymentId);
}
