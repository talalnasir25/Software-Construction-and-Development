// The "Post a trip" form data and its validation (plain Dart, no UI).

import 'models.dart';

class TripDraft {
  String from = '';
  String to = '';
  DateTime? date;

  /// Minutes after midnight (e.g. 8:30 AM = 510).
  int? timeOfDay;
  TripRepeat repeat = TripRepeat.oneTime;
  Set<int> weekdays = {};
  VehicleType vehicleType = VehicleType.car;
  int seats = 3;
  String plate = '';
  PricingMode pricingMode = PricingMode.totalSplit;
  int? price;

  DateTime? get departure {
    if (date == null || timeOfDay == null) return null;
    return DateTime(date!.year, date!.month, date!.day, timeOfDay! ~/ 60, timeOfDay! % 60);
  }
}

/// Each method returns an error message, or null when the value is fine.
class TripValidator {
  static final _plate = RegExp(r'^[A-Z]{2,4}-?\d{1,4}(-?\d{2})?$');

  static String? place(String value, String label) {
    final v = value.trim();
    if (v.isEmpty) return 'Please fill in "$label".';
    if (v.length < 3) return '"$label" must be at least 3 letters.';
    return null;
  }

  static String? route(String from, String to) {
    if (from.trim().isNotEmpty && from.trim().toLowerCase() == to.trim().toLowerCase()) {
      return '"From" and "To" cannot be the same place.';
    }
    return null;
  }

  static String? departure(DateTime? departure, DateTime now) {
    if (departure == null) return 'Please choose a date and time.';
    if (departure.isBefore(now)) return 'Departure must be in the future.';
    if (departure.isAfter(now.add(const Duration(days: 60)))) {
      return 'You can only post trips up to 60 days ahead.';
    }
    return null;
  }

  static String? weekdays(TripRepeat repeat, Set<int> days) {
    if (repeat == TripRepeat.weekdays && days.isEmpty) return 'Pick at least one weekday.';
    return null;
  }

  static String? seats(VehicleType type, int seats) {
    if (seats < 1) return 'At least 1 seat is needed.';
    if (seats > type.maxSeats) {
      return 'A ${type.label.toLowerCase()} can have at most ${type.maxSeats} seat${type.maxSeats == 1 ? '' : 's'}.';
    }
    return null;
  }

  static String? plate(String value) {
    final v = value.trim().toUpperCase();
    if (v.isEmpty) return 'Please enter the number plate.';
    if (!_plate.hasMatch(v)) return 'Use a plate like LEA-1234 or ICT-21-555.';
    return null;
  }

  static String? price(PricingMode mode, int? price) {
    if (price == null) return 'Please enter a price in rupees.';
    if (price < 50) return 'Price must be at least Rs 50.';
    if (price > 20000) return 'Price looks too high (max Rs 20,000).';
    return null;
  }

  /// All errors for the draft (empty list = valid).
  static List<String> validate(TripDraft d, DateTime now) => [
        place(d.from, 'From'),
        place(d.to, 'To'),
        route(d.from, d.to),
        departure(d.departure, now),
        weekdays(d.repeat, d.weekdays),
        seats(d.vehicleType, d.seats),
        plate(d.plate),
        price(d.pricingMode, d.price),
      ].whereType<String>().toList();
}
