import 'package:digimed_connect/features/reviews/review_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reviews are anonymous unless the patient opts in', () {
    final p = buildReviewPayload(appointmentId: '12', overall: 4, subs: {'cleanliness': 5, 'waitingTime': 0}, text: '  Friendly ');
    expect(p, {'appointmentId': 12, 'overall': 4, 'showName': false, 'cleanliness': 5, 'text': 'Friendly'});
    expect(buildReviewPayload(appointmentId: '1', overall: 3, showName: true)['showName'], isTrue);
  });

  test('validation needs an overall rating and caps text', () {
    expect(validateReview(0, ''), isNotNull);
    expect(validateReview(5, 'x' * 501), isNotNull);
    expect(validateReview(5, 'ok'), isNull);
  });

  test('average hidden until three reviews', () {
    expect(ratingLabel(0, null), 'No reviews yet');
    expect(ratingLabel(2, null), contains('rating shows from 3'));
    expect(ratingLabel(3, 4.33), '4.3 out of 5 from 3 reviews');
  });

  test('my review falls back to anonymous name', () {
    final r = MyReview.fromJson({'id': 3, 'overall': 5, 'status': 'PENDING', 'showName': false});
    expect(r.displayName, anonymousName);
  });
}
