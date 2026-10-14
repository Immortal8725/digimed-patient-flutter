import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import 'review_models.dart';
import 'reviews_repository.dart';

/// One-line practice rating for Find Care cards. Hides itself while loading or on error.
class PracticeRatingLine extends ConsumerStatefulWidget {
  const PracticeRatingLine({super.key, required this.tenantId});
  final String tenantId;

  @override
  ConsumerState<PracticeRatingLine> createState() => _PracticeRatingLineState();
}

class _PracticeRatingLineState extends ConsumerState<PracticeRatingLine> {
  static final Map<String, PracticeReviewSummary> _cache = {};
  PracticeReviewSummary? _summary;

  @override
  void initState() {
    super.initState();
    _summary = _cache[widget.tenantId];
    if (_summary == null && widget.tenantId.isNotEmpty) Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant PracticeRatingLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId) {
      setState(() => _summary = _cache[widget.tenantId]);
      if (_summary == null && widget.tenantId.isNotEmpty) Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    try {
      final id = widget.tenantId;
      final s = await ref.read(reviewsRepositoryProvider).summary(id);
      _cache[id] = s;
      if (mounted && id == widget.tenantId) setState(() => _summary = s);
    } catch (_) {
      // Ratings are optional on the card.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    final avg = s.visibleAverage;
    return Text(
      avg == null ? s.label : '${stars(avg.round())}  ${s.label}',
      key: const Key('practice-rating'),
    );
  }
}

/// Published reviews for a practice, with loading, empty and error states and a Report action.
class PracticeReviewsSection extends ConsumerStatefulWidget {
  const PracticeReviewsSection({super.key, required this.tenantId});
  final String tenantId;

  @override
  ConsumerState<PracticeReviewsSection> createState() => _PracticeReviewsSectionState();
}

class _PracticeReviewsSectionState extends ConsumerState<PracticeReviewsSection> {
  bool _loading = true;
  String? _error;
  PracticeReviewsPage? _page;
  final Set<String> _reported = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(reviewsRepositoryProvider).practiceReviews(widget.tenantId);
      if (mounted) setState(() { _page = page; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load reviews.'; _loading = false; });
    }
  }

  Future<void> _report(PublicReview r) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report review'),
        content: TextField(
          controller: reason,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Why should we look at it? (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Report')),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reviewsRepositoryProvider).report(r.id, text);
      setState(() => _reported.add(r.id));
      messenger.showSnackBar(const SnackBar(content: Text('Thanks. The DigiMed team will look at it.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[Text('Patient reviews', style: theme.textTheme.titleMedium)];
    if (_loading) {
      children.add(const Padding(padding: EdgeInsets.all(8), child: Text('Loading reviews...')));
    } else if (_error != null) {
      children.add(Row(children: [
        Expanded(child: Text(_error!)),
        TextButton(onPressed: _load, child: const Text('Try again')),
      ]));
    } else {
      final page = _page!;
      children.add(Text(page.summary.label, key: const Key('practice-rating')));
      if (page.reviews.isEmpty) {
        children.add(const Text('No reviews yet.'));
      }
      for (final r in page.reviews) {
        children.add(Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: Text(r.displayName)), Text(stars(r.overall))]),
                if (r.text.isNotEmpty) Text(r.text),
                if (r.practiceReply.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reply from the practice', style: theme.textTheme.bodySmall),
                  Text(r.practiceReply),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _reported.contains(r.id) ? null : () => _report(r),
                    child: Text(_reported.contains(r.id) ? 'Reported' : 'Report'),
                  ),
                ),
              ],
            ),
          ),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
