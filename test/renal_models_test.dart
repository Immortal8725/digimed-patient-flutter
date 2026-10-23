import 'package:digimed_connect/features/renal/renal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upcoming parses sessions, trips and ETA', () {
    final u = RenalUpcoming({
      'homeAddress': '12 Main Rd',
      'homePinSet': true,
      'sessions': [
        {
          'sessionId': 5,
          'date': '2026-10-24',
          'startTime': '07:00',
          'offersMeals': true,
          'trips': [
            {
              'id': 9,
              'direction': 'TO_CENTRE',
              'pickupTime': '06:15',
              'status': 'SCHEDULED',
              'confirmation': 'PENDING',
              'etaMinutes': 12,
              'etaSource': 'ESTIMATE',
              'driverLat': -26.1,
              'driverLng': 28.0,
            },
            {'id': 10, 'direction': 'TO_HOME', 'status': 'DROPPED_OFF'},
          ],
        },
      ],
    });
    expect(u.homePinSet, isTrue);
    final trips = u.sessions.single.trips;
    expect(trips.first.directionLabel, 'Lift to the unit');
    expect(trips.first.editable, isTrue);
    expect(trips.first.etaLabel, 'Driver roughly 12 minutes away (estimate)');
    expect(trips.first.driverLive, isTrue);
    expect(trips.first.confirmationLabel, 'Please confirm or cancel');
    expect(trips.last.directionLabel, 'Lift home');
    expect(trips.last.editable, isFalse);
    expect(trips.last.etaLabel, isNull);
  });

  test('route ETA reads as by road', () {
    final t = RenalTrip({'etaMinutes': 1, 'etaSource': 'ROUTE'});
    expect(t.etaLabel, 'Driver about 1 minute away by road');
  });

  test('pin validation', () {
    expect(validatePin(null, 28), isNotNull);
    expect(validatePin(-91, 28), isNotNull);
    expect(validatePin(-26, 181), isNotNull);
    expect(validatePin(-26.2, 28.04), isNull);
    expect(mapLink(-26.2, 28.04), contains('query=-26.2,28.04'));
  });

  test('meal preference payload trims and de-duplicates', () {
    final p = buildMealPreferencePayload(
      usualFoods: '  pap ',
      allergies: ['NUTS', 'NUTS'],
      dislikes: ' ',
    );
    expect(p['usualFoods'], 'pap');
    expect(p['allergies'], ['NUTS']);
    expect(p['dislikes'], isNull);
    expect(p['restrictions'], isEmpty);
  });

  test('meal options flag allergy clashes', () {
    final prefs = MealPreferences({
      'allergenChoices': [
        {'code': 'NUTS', 'label': 'Nuts'},
      ],
      'options': [
        {
          'code': 'STANDARD',
          'label': 'Standard',
          'blocked': true,
          'allergyConflicts': ['Nuts'],
        },
      ],
    });
    expect(prefs.allergenChoices.single.label, 'Nuts');
    expect(prefs.options.single.blocked, isTrue);
    expect(prefs.options.single.conflicts, ['Nuts']);
  });
}
