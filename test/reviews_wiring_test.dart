import 'package:digimed_connect/core/network/api_client.dart';
import 'package:digimed_connect/core/network/api_exception.dart';
import 'package:digimed_connect/core/storage/token_store.dart';
import 'package:digimed_connect/features/reviews/practice_reviews_widgets.dart';
import 'package:digimed_connect/features/reviews/review_models.dart';
import 'package:digimed_connect/features/reviews/reviews_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi implements ApiClient {
  final calls = <String>[];
  Object? Function(String method, String path, Object? data, Map<String, dynamic>? query)? reply;

  @override
  TokenStore get store => throw UnimplementedError();
  @override
  void Function()? onUnauthorized;

  Future<Object?> _go(String m, String p, [Object? d, Map<String, dynamic>? q]) async {
    calls.add('$m $p${q == null ? '' : ' $q'}');
    return reply?.call(m, p, d, q);
  }

  @override
  Future<Object?> get(String path, {Map<String, dynamic>? query}) => _go('GET', path, null, query);
  @override
  Future<Object?> post(String path, {Object? data, Map<String, dynamic>? query}) => _go('POST', path, data, query);
  @override
  Future<Object?> put(String path, {Object? data, Map<String, dynamic>? query}) => _go('PUT', path, data, query);
  @override
  Future<Object?> delete(String path) => _go('DELETE', path);
}

Widget wrap(FakeApi api, Widget child) => ProviderScope(
  overrides: [reviewsRepositoryProvider.overrideWithValue(ReviewsRepository(api))],
  child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
);

void main() {
  test('repository calls the backend endpoints', () async {
    final api = FakeApi();
    final repo = ReviewsRepository(api);
    api.reply = (m, p, d, q) => p.contains('summaries') ? {'5': {'count': 3, 'average': 4.2}} : p.contains('/reviews') && m == 'GET' && p.startsWith('/public') ? {'count': 0, 'reviews': []} : [];
    await repo.eligible();
    await repo.mine();
    await repo.create({'appointmentId': 1, 'overall': 4});
    await repo.withdrawName('9');
    await repo.delete('9');
    await repo.report('9', 'x');
    final s = await repo.summary('5');
    await repo.practiceReviews('5');
    expect(api.calls, [
      'GET /api/reviews/eligible',
      'GET /api/reviews/mine',
      'POST /api/reviews',
      'POST /api/reviews/9/withdraw-name',
      'DELETE /api/reviews/9',
      'POST /api/reviews/9/report',
      'GET /public/practices/review-summaries {tenantIds: 5}',
      'GET /public/practices/5/reviews',
    ]);
    expect(s.visibleAverage, 4.2);
  });

  test('summary hides average below three', () {
    expect(PracticeReviewSummary(2, 4.5).visibleAverage, isNull);
    expect(PracticeReviewSummary(2, 4.5).label, contains('rating shows from 3'));
  });

  testWidgets('reviews section: loading, then reviews with report', (tester) async {
    final api = FakeApi();
    api.reply = (m, p, d, q) => {
      'count': 3, 'average': 4.0,
      'reviews': [{'id': 1, 'displayName': 'Anonymous patient', 'overall': 4, 'text': 'Quick', 'practiceReply': 'Thanks'}],
    };
    await tester.pumpWidget(wrap(api, const PracticeReviewsSection(tenantId: '5')));
    expect(find.text('Loading reviews...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('4.0 out of 5 from 3 reviews'), findsOneWidget);
    expect(find.text('Anonymous patient'), findsOneWidget);
    expect(find.text('Thanks'), findsOneWidget);
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Report'));
    await tester.pumpAndSettle();
    expect(api.calls.last, 'POST /api/reviews/1/report');
    expect(find.text('Reported'), findsOneWidget);
  });

  testWidgets('reviews section: empty state', (tester) async {
    final api = FakeApi()..reply = (m, p, d, q) => {'count': 0, 'reviews': []};
    await tester.pumpWidget(wrap(api, const PracticeReviewsSection(tenantId: '5')));
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet.'), findsOneWidget);
  });

  testWidgets('reviews section: error state and retry', (tester) async {
    final api = FakeApi()..reply = (m, p, d, q) => throw ApiException('down');
    await tester.pumpWidget(wrap(api, const PracticeReviewsSection(tenantId: '5')));
    await tester.pumpAndSettle();
    expect(find.text('Could not load reviews.'), findsOneWidget);
    api.reply = (m, p, d, q) => {'count': 0, 'reviews': []};
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet.'), findsOneWidget);
  });

  testWidgets('rating line shows label and hides on error', (tester) async {
    final api = FakeApi()..reply = (m, p, d, q) => {'7': {'count': 4, 'average': 3.5}};
    await tester.pumpWidget(wrap(api, const PracticeRatingLine(tenantId: '7')));
    await tester.pumpAndSettle();
    expect(find.textContaining('3.5 out of 5 from 4 reviews'), findsOneWidget);
    final bad = FakeApi()..reply = (m, p, d, q) => throw ApiException('down');
    await tester.pumpWidget(wrap(bad, const PracticeRatingLine(tenantId: '8')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-rating')), findsNothing);
  });
}
