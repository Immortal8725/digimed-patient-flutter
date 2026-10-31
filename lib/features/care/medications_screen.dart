import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'care_repository.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  bool _loading = true;
  String? _error;
  String? _info;
  List<Map<String, dynamic>> _meds = [];
  List<Map<String, dynamic>> _today = [];

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
      final meds = await repo.medications();
      final today = await repo.dosesToday();
      if (!mounted) return;
      setState(() {
        _meds = meds;
        _today = today;
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

  Future<void> _act(Map<String, dynamic> slot, String action) async {
    final label = switch (action) {
      'TAKEN' => 'Confirm dose taken',
      'SNOOZED' => 'Snooze this dose?',
      _ => 'Skip this dose?',
    };
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text(firstString(slot, ['medicationName', 'name', 'drugName'])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      final message = await ref
          .read(careRepositoryProvider)
          .logDose(
            medicationId: firstString(slot, ['medicationId', 'id']),
            action: action,
            reminderId: firstString(slot, ['reminderId']),
            scheduledAt: firstString(slot, ['scheduledAt']),
          );
      if (!mounted) return;
      setState(() => _info = message);
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My medications')),
      body: _loading
          ? const LoadingView(label: 'Loading medications')
          : _error != null && _meds.isEmpty && _today.isEmpty
          ? ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_info != null) Text(_info!),
                  if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  HeartSection(
                    'Today\'s doses',
                    _today.isEmpty
                        ? const HeartCard(
                            child: HeartEmptyBox('No doses were returned for today.', icon: Icons.medication_outlined),
                          )
                        : Column(children: [for (final slot in _today) _dose(slot)]),
                    subtitle: 'Taken, snooze, or skip.',
                  ),
                  const SizedBox(height: 16),
                  HeartSection(
                    'Active medicines',
                    _meds.isEmpty
                        ? const HeartCard(
                            child: HeartEmptyBox(
                              'No active medicines on file.',
                              icon: Icons.medication_liquid_outlined,
                            ),
                          )
                        : Column(
                            children: [
                              for (final med in _meds)
                                HeartTile(
                                  icon: Icons.medication_outlined,
                                  title: firstString(med, ['name', 'drugName', 'medicationName']),
                                  subtitle: [
                                    firstString(med, ['dose', 'dosage', 'strength']),
                                    firstString(med, ['instructions', 'frequency']),
                                  ].where((part) => part.isNotEmpty).join(' '),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _dose(Map<String, dynamic> slot) {
    final action = firstString(slot, ['action']).toUpperCase();
    final pending = action.isEmpty || action == 'PENDING' || action == 'SNOOZED';
    return HeartCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(firstString(slot, ['medicationName', 'name', 'drugName'])),
            Text(firstString(slot, ['scheduledAt', 'time'])),
            if (!pending) Text(action),
            if (pending)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(onPressed: () => _act(slot, 'TAKEN'), child: const Text('Taken')),
                  OutlinedButton(onPressed: () => _act(slot, 'SNOOZED'), child: const Text('Snooze')),
                  TextButton(onPressed: () => _act(slot, 'SKIPPED'), child: const Text('Skip')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
