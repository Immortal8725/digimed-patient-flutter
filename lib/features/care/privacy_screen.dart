import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'care_repository.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _info;
  String _text = '';
  String _shownAt = '';

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
      final repo = ref.read(careRepositoryProvider);
      final notice = await repo.privacyNotice();
      var text = firstString(notice, ['text', 'body', 'notice', 'content']);
      if (text.isEmpty) {
        final policy = await repo.privacyPolicy();
        text = firstString(policy, ['text', 'body', 'content', 'html']);
      }
      String shown = '';
      try {
        shown = await repo.privacyShownAt();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _text = text;
        _shownAt = shown;
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

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final shown = await ref.read(careRepositoryProvider).confirmPrivacyShown();
      if (!mounted) return;
      setState(() {
        _shownAt = shown.isEmpty ? DateTime.now().toIso8601String() : shown;
        _info = 'Your confirmation was recorded.';
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy notice')),
      body: _loading
          ? const LoadingView(label: 'Loading the privacy notice')
          : _error != null && _text.isEmpty
          ? ErrorView(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'DigiMed Connect privacy notice under POPIA. Confirm when you have read it.',
                ),
                const SizedBox(height: 12),
                Text(_text.isEmpty ? 'The clinic has not published notice text yet.' : _text),
                if (_shownAt.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Last confirmed: $_shownAt'),
                ],
                if (_info != null) Text(_info!),
                if (_error != null) Text(_error!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving || _text.isEmpty ? null : _confirm,
                  child: Text(_saving ? 'Saving...' : _shownAt.isEmpty ? 'I have read this' : 'Confirm again'),
                ),
              ],
            ),
    );
  }
}
