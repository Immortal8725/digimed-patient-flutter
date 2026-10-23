import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_client.dart';
import 'renal_models.dart';

class RenalRepository {
  RenalRepository(this._api);
  final ApiClient _api;

  Future<RenalUpcoming> upcoming() async =>
      RenalUpcoming(asMap(await _api.get('/api/patient/renal/upcoming')));

  Future<String> confirmTrip(
    String tripId, {
    required bool confirmed,
    bool wholeDay = false,
  }) async {
    final data = await _api.put(
      '/api/patient/renal/trips/$tripId/confirm',
      data: {'confirmed': confirmed, 'wholeDay': wholeDay},
    );
    return apiMessage(data, confirmed ? 'Lift confirmed' : 'Lift cancelled');
  }

  Future<void> setTripPin(
    String tripId,
    double lat,
    double lng, {
    double? accuracy,
  }) async {
    await _api.put(
      '/api/patient/renal/trips/$tripId/pin',
      data: {'lat': lat, 'lng': lng, 'accuracy': accuracy},
    );
  }

  Future<void> clearTripPin(String tripId) async =>
      _api.delete('/api/patient/renal/trips/$tripId/pin');

  Future<void> setHomePin(double lat, double lng, {double? accuracy}) async {
    await _api.put(
      '/api/patient/renal/home-pin',
      data: {'lat': lat, 'lng': lng, 'accuracy': accuracy},
    );
  }

  Future<void> clearHomePin() async =>
      _api.delete('/api/patient/renal/home-pin');

  Future<MealPreferences> mealPreferences() async => MealPreferences(
    asMap(await _api.get('/api/patient/renal/meal-preferences')),
  );

  Future<MealPreferences> saveMealPreferences(
    Map<String, dynamic> payload,
  ) async => MealPreferences(
    asMap(await _api.put('/api/patient/renal/meal-preferences', data: payload)),
  );

  Future<void> chooseMeal(
    String sessionId,
    String mealOption, {
    String notes = '',
  }) async {
    await _api.put(
      '/api/patient/renal/sessions/$sessionId/meal',
      data: {
        'mealOption': mealOption,
        'notes': notes.trim().isEmpty ? null : notes.trim(),
      },
    );
  }
}

final renalRepositoryProvider = Provider<RenalRepository>(
  (ref) => RenalRepository(ref.watch(apiClientProvider)),
);
