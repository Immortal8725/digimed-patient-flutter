import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_client.dart';
import 'review_models.dart';

class ReviewsRepository {
  ReviewsRepository(this._api);
  final ApiClient _api;

  Future<List<ReviewVisit>> eligible() async {
    final data = await _api.get('/api/reviews/eligible');
    return asList(data).map(asMap).map(ReviewVisit.fromJson).toList();
  }

  Future<List<MyReview>> mine() async {
    final data = await _api.get('/api/reviews/mine');
    return asList(data).map(asMap).map(MyReview.fromJson).toList();
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _api.post('/api/reviews', data: payload);
  }

  Future<void> withdrawName(String id) async {
    await _api.post('/api/reviews/$id/withdraw-name');
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/reviews/$id');
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => ReviewsRepository(ref.watch(apiClientProvider)),
);
