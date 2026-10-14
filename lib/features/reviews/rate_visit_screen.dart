import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import 'review_models.dart';
import 'reviews_repository.dart';

class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged, required this.label});
  final int value;
  final ValueChanged<int> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$label $i of 5',
            visualDensity: VisualDensity.compact,
            icon: Icon(i <= value ? Icons.star : Icons.star_border, color: Colors.amber),
            onPressed: () => onChanged(i == value ? 0 : i),
          ),
      ],
    );
  }
}

class RateVisitScreen extends ConsumerStatefulWidget {
  const RateVisitScreen({super.key, required this.appointmentId, this.practiceName = ''});
  final String appointmentId;
  final String practiceName;

  @override
  ConsumerState<RateVisitScreen> createState() => _RateVisitScreenState();
}

class _RateVisitScreenState extends ConsumerState<RateVisitScreen> {
  final _text = TextEditingController();
  int _overall = 0;
  final Map<String, int> _subs = {};
  bool _showName = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final problem = validateReview(_overall, _text.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(reviewsRepositoryProvider).create(buildReviewPayload(
        appointmentId: widget.appointmentId,
        overall: _overall,
        subs: _subs,
        text: _text.text,
        showName: _showName,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thanks. We'll check your review before it goes live.")),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your visit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.practiceName.isNotEmpty)
            Text(widget.practiceName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(padding: const EdgeInsets.all(12), child: Text(reviewNotice)),
          ),
          const SizedBox(height: 12),
          const Text('Overall experience'),
          StarPicker(value: _overall, label: 'Overall', onChanged: (v) => setState(() => _overall = v)),
          const SizedBox(height: 8),
          for (final (key, label) in subRatings)
            Row(
              children: [
                Expanded(child: Text('$label (optional)')),
                StarPicker(
                  value: _subs[key] ?? 0,
                  label: label,
                  onChanged: (v) => setState(() => v == 0 ? _subs.remove(key) : _subs[key] = v),
                ),
              ],
            ),
          TextField(
            controller: _text,
            maxLength: maxReviewText,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Tell others about the experience (optional)'),
          ),
          const Text('Your review shows as Anonymous patient unless you tick the box below.'),
          CheckboxListTile(
            key: const Key('name-opt-in'),
            contentPadding: EdgeInsets.zero,
            value: _showName,
            onChanged: (v) => setState(() => _showName = v == true),
            title: const Text(nameOptInLabel),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Sending...' : 'Send review'),
          ),
        ],
      ),
    );
  }
}
