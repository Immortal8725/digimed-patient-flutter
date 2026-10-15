import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'rate_visit_screen.dart';
import 'review_models.dart';
import 'reviews_repository.dart';

class MyReviewsScreen extends ConsumerStatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  ConsumerState<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends ConsumerState<MyReviewsScreen> {
  bool _loading = true;
  String? _error;
  List<ReviewVisit> _eligible = [];
  List<MyReview> _mine = [];

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
      final repo = ref.read(reviewsRepositoryProvider);
      final eligible = await repo.eligible();
      final mine = await repo.mine();
      if (!mounted) return;
      setState(() {
        _eligible = eligible;
        _mine = mine;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _rate(ReviewVisit v) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RateVisitScreen(appointmentId: v.appointmentId, practiceName: v.practiceName),
      ),
    );
    if (done == true) _load();
  }

  Future<void> _act(Future<void> Function() fn, String ok) async {
    try {
      await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
      _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _delete(MyReview r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This removes it for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await _act(() => ref.read(reviewsRepositoryProvider).delete(r.id), 'Review deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(reviewsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My reviews')),
      body: _loading
          ? const LoadingView(label: 'Loading reviews')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  Text('Rate your visit', style: Theme.of(context).textTheme.titleMedium),
                  if (_eligible.isEmpty) const Text('No completed visits waiting for a rating.'),
                  for (final v in _eligible)
                    Card(
                      child: ListTile(
                        title: Text(v.practiceName.isEmpty ? 'Your practice' : v.practiceName),
                        subtitle: Text('Visit on ${v.date}'),
                        trailing: FilledButton(onPressed: () => _rate(v), child: const Text('Rate')),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Reviews you wrote', style: Theme.of(context).textTheme.titleMedium),
                  if (_mine.isEmpty) const Text('You have not written any reviews yet.'),
                  for (final r in _mine)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.practiceName.isEmpty ? 'Practice' : r.practiceName,
                                style: Theme.of(context).textTheme.titleSmall),
                            Text('${'★' * r.overall}${'☆' * (5 - r.overall)}  ${reviewStatusLabels[r.status] ?? r.status}'),
                            if (r.text.isNotEmpty) Text(r.text),
                            Text('Shown as: ${r.displayName}', style: Theme.of(context).textTheme.bodySmall),
                            if (r.rejectionReason.isNotEmpty) Text('Reason: ${r.rejectionReason}'),
                            Row(
                              children: [
                                if (r.showName)
                                  TextButton(
                                    onPressed: () => _act(() => repo.withdrawName(r.id), 'Your review is now anonymous.'),
                                    child: const Text('Go anonymous'),
                                  ),
                                TextButton(onPressed: () => _delete(r), child: const Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
