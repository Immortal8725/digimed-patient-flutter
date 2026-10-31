import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'care_repository.dart';

class RightsScreen extends ConsumerStatefulWidget {
  const RightsScreen({super.key});

  @override
  ConsumerState<RightsScreen> createState() => _RightsScreenState();
}

class _RightsScreenState extends ConsumerState<RightsScreen> {
  final _reason = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _info;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(careRepositoryProvider).rightsRequests();
      if (!mounted) return;
      setState(() {
        _requests = rows;
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

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await ref.read(careRepositoryProvider).exportData();
      final text = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      setState(() => _info = 'A copy of your data was copied to the clipboard.');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your data copy'),
          content: SingleChildScrollView(child: SelectableText(text)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _erase() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Add a short reason for the erasure request.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(careRepositoryProvider).erasureRequest(_reason.text.trim());
      _reason.clear();
      if (!mounted) return;
      setState(() => _info = 'Erasure request sent. The clinic still holds the record until they act on it.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My data rights')),
      body: _loading
          ? const LoadingView(label: 'Loading requests')
          : HeartFormPanel(
              title: 'My Data Rights',
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Download a copy of your data, or ask the clinic to consider erasure. This page does not delete your record.',
                ),
                if (_info != null) Text(_info!),
                if (_error != null) Text(_error!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _export, child: const Text('Copy my data')),
                const SizedBox(height: 16),
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(labelText: 'Reason for erasure request'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _busy ? null : _erase, child: const Text('Send erasure request')),
                const SizedBox(height: 16),
                HeartHeader('Requests'),
                if (_requests.isEmpty) const HeartEmptyBox('No requests yet.'),
                for (final request in _requests)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(firstString(request, ['requestType', 'kind', 'action', 'type'])),
                    subtitle: Text(
                      '${firstString(request, ['status'])} ${firstString(request, ['reason', 'createdAt'])}',
                    ),
                  ),
              ],
            ),
    );
  }
}
