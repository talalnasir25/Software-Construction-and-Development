// Plain data classes for Carp. No Flutter imports here, so they are easy to
// test and easy to map to/from JSON when the real backend arrives.

enum VehicleType {
  car('Car', 4),
  bike('Bike', 1);

  const VehicleType(this.label, this.maxSeats);
  final String label;
  final int maxSeats;
}

enum PricingMode {
  totalSplit('Total split'),
  perSeat('Per seat');

  const PricingMode(this.label);
  final String label;
}

enum TripRepeat {
  oneTime('One-time'),
  daily('Daily'),
  weekdays('Chosen weekdays');

  const TripRepeat(this.label);
  final String label;
}

enum TripStatus { open, confirmed, cancelled }

enum BookingStatus { joined, cancelled }

/// Kinds of money movement. Every rupee is recorded as a ledger entry.
enum LedgerType {
  charge('Trip charge'),
  penalty('Cancellation penalty'),
  reversal('Reversal'),
  payment('Payment'),
  credit('Credit');

  const LedgerType(this.label);
  final String label;
}

enum PaymentMethod {
  cash('Cash'),
  jazzCash('JazzCash'),
  easypaisa('Easypaisa'),
  nayaPay('NayaPay');

  const PaymentMethod(this.label);
  final String label;
}

enum PaymentStatus { pending, confirmed, rejected }

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.vehicleType,
    this.vehicleModel = '',
    this.plate = '',
  });

  final String id;
  String name;
  final String email;
  String phone;
  VehicleType? vehicleType;
  String vehicleModel;
  String plate;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
  }
}

/// One change to attendance after a trip was confirmed (shown to riders).
class TripEdit {
  TripEdit({required this.at, required this.summary});
  final DateTime at;
  final String summary;
}

class Trip {
  Trip({
    required this.id,
    required this.driverId,
    required this.from,
    required this.to,
    required this.departure,
    required this.repeat,
    this.weekdays = const {},
    required this.vehicleType,
    required this.seats,
    required this.plate,
    required this.pricingMode,
    required this.price,
    required this.createdAt,
    this.status = TripStatus.open,
    this.confirmedAt,
  });

  final String id;
  final String driverId;
  final String from;
  final String to;
  final DateTime departure;
  final TripRepeat repeat;

  /// 1 = Monday ... 7 = Sunday (same as DateTime.weekday).
  final Set<int> weekdays;
  final VehicleType vehicleType;
  final int seats;
  final String plate;
  final PricingMode pricingMode;

  /// Total trip price (total split) or price per seat (per seat), in rupees.
  final int price;
  final DateTime createdAt;
  TripStatus status;
  DateTime? confirmedAt;
  final List<TripEdit> editHistory = [];

  bool get isEdited => editHistory.isNotEmpty;
}

class Booking {
  Booking({
    required this.id,
    required this.tripId,
    required this.riderId,
    required this.joinedAt,
    this.status = BookingStatus.joined,
    this.present = true, // riders default to PRESENT
  });

  final String id;
  final String tripId;
  final String riderId;
  final DateTime joinedAt;
  BookingStatus status;
  bool present;
}

/// Money between one rider and one driver.
/// Positive amount = rider owes driver more. Negative = rider gets credit.
class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.riderId,
    required this.driverId,
    required this.type,
    required this.amount,
    required this.note,
    required this.createdAt,
    this.tripId,
  });

  final String id;
  final String riderId;
  final String driverId;
  final String? tripId;
  final LedgerType type;
  final int amount;
  final String note;
  final DateTime createdAt;
}

class Payment {
  Payment({
    required this.id,
    required this.riderId,
    required this.driverId,
    required this.amount,
    required this.method,
    required this.createdAt,
    this.status = PaymentStatus.pending,
  });

  final String id;
  final String riderId;
  final String driverId;
  final int amount;
  final PaymentMethod method;
  final DateTime createdAt;
  PaymentStatus status;
}

class Dispute {
  Dispute({
    required this.id,
    required this.tripId,
    required this.riderId,
    required this.entryId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String riderId;
  final String entryId;
  final String reason;
  final DateTime createdAt;
}
