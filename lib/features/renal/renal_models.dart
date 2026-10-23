import '../../core/json/json_values.dart';

/// One lift (to or from the unit) from /api/patient/renal/upcoming.
class RenalTrip {
  RenalTrip(this.raw);
  final Map<String, dynamic> raw;

  String get id => str(raw['id']);
  String get direction => str(raw['direction']).toUpperCase();
  String get directionLabel =>
      direction == 'TO_HOME' ? 'Lift home' : 'Lift to the unit';
  String get pickupTime => str(raw['pickupTime']);
  String get arrivalTime => str(raw['arrivalTime']);
  String get pickupAddress => str(raw['pickupAddress']);
  bool get pinSet => asBool(raw['pickupPinSet']);
  String get status => str(raw['status']).toUpperCase();
  String get confirmation => str(raw['confirmation']).toUpperCase();
  bool get editable => status == 'SCHEDULED';
  String get driverFirstName => str(raw['driverFirstName']);
  String get vehicle => [
    str(raw['vehicle']),
    str(raw['vehicleRegistration']),
  ].where((s) => s.isNotEmpty).join(' ');
  int? get etaMinutes => asInt(raw['etaMinutes']);
  bool get etaIsRoute => str(raw['etaSource']).toUpperCase() == 'ROUTE';
  double? get driverLat => _dbl(raw['driverLat']);
  double? get driverLng => _dbl(raw['driverLng']);
  bool get driverLive => driverLat != null && driverLng != null;

  String get confirmationLabel => switch (confirmation) {
    'CONFIRMED' => 'You confirmed this lift',
    'DECLINED' => 'You cancelled this lift',
    _ => 'Please confirm or cancel',
  };

  String? get etaLabel {
    final m = etaMinutes;
    if (m == null) return null;
    final word = m == 1 ? 'minute' : 'minutes';
    return etaIsRoute
        ? 'Driver about $m $word away by road'
        : 'Driver roughly $m $word away (estimate)';
  }
}

class RenalSessionDay {
  RenalSessionDay(this.raw);
  final Map<String, dynamic> raw;

  String get sessionId => str(raw['sessionId']);
  String get date => str(raw['date']);
  String get startTime => str(raw['startTime']);
  String get endTime => str(raw['endTime']);
  bool get offersTransport => asBool(raw['offersTransport']);
  bool get offersMeals => asBool(raw['offersMeals']);
  String get meal => str(raw['meal']);
  String get mealNotes => str(raw['mealNotes']);
  List<RenalTrip> get trips =>
      asList(raw['trips']).map(asMap).map(RenalTrip.new).toList();
}

class RenalUpcoming {
  RenalUpcoming(this.raw);
  final Map<String, dynamic> raw;

  String get homeAddress => str(raw['homeAddress']);
  bool get homePinSet => asBool(raw['homePinSet']);
  List<RenalSessionDay> get sessions =>
      asList(raw['sessions']).map(asMap).map(RenalSessionDay.new).toList();
}

class MealChoice {
  MealChoice(this.code, this.label);
  final String code;
  final String label;
}

class MealOption {
  MealOption(this.raw);
  final Map<String, dynamic> raw;
  String get code => str(raw['code']);
  String get label => str(raw['label']);
  String get description => str(raw['description']);
  bool get blocked => asBool(raw['blocked']);
  List<String> get conflicts =>
      asList(raw['allergyConflicts']).map(str).toList();
  List<String> get mismatches =>
      asList(raw['restrictionMismatch']).map(str).toList();
}

class MealPreferences {
  MealPreferences(this.raw);
  final Map<String, dynamic> raw;
  String get usualFoods => str(raw['usualFoods']);
  List<String> get allergies => asList(raw['allergies']).map(str).toList();
  String get otherAllergies => str(raw['otherAllergies']);
  String get dislikes => str(raw['dislikes']);
  List<String> get restrictions =>
      asList(raw['restrictions']).map(str).toList();
  List<MealChoice> get allergenChoices => _choices(raw['allergenChoices']);
  List<MealChoice> get restrictionChoices =>
      _choices(raw['restrictionChoices']);
  List<MealOption> get options =>
      asList(raw['options']).map(asMap).map(MealOption.new).toList();
}

List<MealChoice> _choices(Object? v) =>
    asList(v)
        .map(asMap)
        .map((m) => MealChoice(str(m['code']), str(m['label'])))
        .toList();

double? _dbl(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(str(v));
}

/// Body for PUT /api/patient/renal/meal-preferences. Trims text and drops blanks.
Map<String, dynamic> buildMealPreferencePayload({
  String usualFoods = '',
  Iterable<String> allergies = const [],
  String otherAllergies = '',
  String dislikes = '',
  Iterable<String> restrictions = const [],
}) {
  String? t(String s) => s.trim().isEmpty ? null : s.trim();
  return {
    'usualFoods': t(usualFoods),
    'allergies': allergies.toSet().toList(),
    'otherAllergies': t(otherAllergies),
    'dislikes': t(dislikes),
    'restrictions': restrictions.toSet().toList(),
  };
}

/// Checks a GPS pin before it is sent. Returns an error message or null.
String? validatePin(double? lat, double? lng) {
  if (lat == null || lng == null) {
    return 'Latitude and longitude are both needed';
  }
  if (lat < -90 || lat > 90) return 'Latitude must be between -90 and 90';
  if (lng < -180 || lng > 180) return 'Longitude must be between -180 and 180';
  return null;
}

/// A Google Maps link to the driver's last shared spot.
String mapLink(double lat, double lng) =>
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
