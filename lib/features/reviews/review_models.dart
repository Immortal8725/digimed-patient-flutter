import '../../core/json/json_values.dart';

const maxReviewText = 500;
const minForAverage = 3;
const anonymousName = 'Anonymous patient';
const reviewNotice =
    "Please don't include health details, like a diagnosis, test results or medicine. "
    "Rate the experience only. The practice won't see who you are.";
const nameOptInLabel =
    'Show my first name and surname initial on this review (for example Thabo M.). '
    'You can switch back to anonymous later.';

const subRatings = [
  ('waitingTime', 'Waiting time'),
  ('staffCourtesy', 'Staff courtesy'),
  ('cleanliness', 'Cleanliness'),
  ('bookingEase', 'Booking ease'),
  ('billingClarity', 'Billing clarity'),
];

const reviewStatusLabels = {
  'PENDING': 'Waiting for checks',
  'PUBLISHED': 'Published',
  'REJECTED': 'Not published',
};

/// Builds the create payload. Anonymous unless [showName] is explicitly true.
Map<String, dynamic> buildReviewPayload({
  required String appointmentId,
  required int overall,
  Map<String, int> subs = const {},
  String text = '',
  bool showName = false,
}) {
  final payload = <String, dynamic>{
    'appointmentId': int.tryParse(appointmentId) ?? appointmentId,
    'overall': overall,
    'showName': showName,
  };
  for (final (key, _) in subRatings) {
    final v = subs[key];
    if (v != null && v >= 1 && v <= 5) payload[key] = v;
  }
  final t = text.trim();
  if (t.isNotEmpty) payload['text'] = t;
  return payload;
}

String? validateReview(int overall, String text) {
  if (overall < 1 || overall > 5) return 'Pick an overall rating';
  if (text.trim().length > maxReviewText) return 'Keep it under $maxReviewText characters';
  return null;
}

String ratingLabel(int count, double? average) {
  if (count == 0) return 'No reviews yet';
  if (average == null || count < minForAverage) {
    return '$count review${count == 1 ? '' : 's'} (rating shows from $minForAverage)';
  }
  return '${average.toStringAsFixed(1)} out of 5 from $count reviews';
}

class ReviewVisit {
  ReviewVisit(this.appointmentId, this.practiceName, this.date);
  factory ReviewVisit.fromJson(Map<String, dynamic> j) =>
      ReviewVisit(str(j['appointmentId']), str(j['practiceName']), str(j['appointmentDate']));
  final String appointmentId;
  final String practiceName;
  final String date;
}

class MyReview {
  MyReview({
    required this.id,
    required this.practiceName,
    required this.status,
    required this.overall,
    required this.text,
    required this.showName,
    required this.displayName,
    required this.rejectionReason,
  });
  factory MyReview.fromJson(Map<String, dynamic> j) => MyReview(
    id: str(j['id']),
    practiceName: str(j['practiceName']),
    status: str(j['status']),
    overall: asInt(j['overall']) ?? 0,
    text: str(j['text']),
    showName: asBool(j['showName']),
    displayName: str(j['displayName']).isEmpty ? anonymousName : str(j['displayName']),
    rejectionReason: str(j['rejectionReason']),
  );
  final String id;
  final String practiceName;
  final String status;
  final int overall;
  final String text;
  final bool showName;
  final String displayName;
  final String rejectionReason;
}

class PracticeReviewSummary {
  PracticeReviewSummary(this.count, this.average);
  factory PracticeReviewSummary.fromJson(Map<String, dynamic> j) {
    final avg = j['average'];
    return PracticeReviewSummary(asInt(j['count']) ?? 0, avg is num ? avg.toDouble() : double.tryParse(str(avg)));
  }
  final int count;
  final double? average;

  /// Average only counts once there are enough published reviews.
  double? get visibleAverage => count >= minForAverage ? average : null;
  String get label => ratingLabel(count, visibleAverage);
}

class PublicReview {
  PublicReview(this.id, this.displayName, this.overall, this.text, this.practiceReply);
  factory PublicReview.fromJson(Map<String, dynamic> j) => PublicReview(
    str(j['id']),
    str(j['displayName']).isEmpty ? anonymousName : str(j['displayName']),
    asInt(j['overall']) ?? 0,
    str(j['text']),
    str(j['practiceReply']),
  );
  final String id;
  final String displayName;
  final int overall;
  final String text;
  final String practiceReply;
}

class PracticeReviewsPage {
  PracticeReviewsPage(this.summary, this.reviews);
  factory PracticeReviewsPage.fromJson(Map<String, dynamic> j) => PracticeReviewsPage(
    PracticeReviewSummary.fromJson(j),
    asList(j['reviews']).map(asMap).map(PublicReview.fromJson).toList(),
  );
  final PracticeReviewSummary summary;
  final List<PublicReview> reviews;
}

String stars(int n) => '${'\u2605' * n.clamp(0, 5)}${'\u2606' * (5 - n.clamp(0, 5))}';
