import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'care_repository.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _loading = true;
  bool _accepted = false;
  String? _error;
  String? _info;
  String _patientId = '';
  String _tenantId = '';
  String _consentId = '';
  List<Map<String, dynamic>> _doctors = [];
  String? _doctorId;
  String _grantType = 'PERMANENT';

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
      final profile = await repo.profile();
      _patientId = firstString(profile, ['id', 'patientId']);
      _tenantId = firstString(profile, ['tenantId']);
      if (_patientId.isNotEmpty) {
        final check = await repo.consentCheck(_patientId);
        _accepted = asBool(check['accepted']);
        _consentId = firstString(check, ['id', 'consentId']);
      }
      if (_tenantId.isNotEmpty) {
        try {
          _doctors = await repo.doctors(_tenantId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _save(bool accepted) async {
    try {
      final saved = await ref.read(careRepositoryProvider).saveConsent(
        patientId: _patientId,
        accepted: accepted,
      );
      if (!mounted) return;
      setState(() {
        _accepted = accepted;
        _consentId = firstString(saved, ['id', 'consentId']).isEmpty
            ? _consentId
            : firstString(saved, ['id', 'consentId']);
        _info = accepted
            ? 'Consent saved. Clinics can request paperless access.'
            : 'Consent withdrawn. Paperless access stays closed until you agree again.';
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _grant() async {
    if (!_accepted) {
      setState(() => _info = 'Give data-processing consent before granting a doctor access.');
      return;
    }
    if (_doctorId == null || _doctorId!.isEmpty) return;
    try {
      await ref.read(careRepositoryProvider).grantDoctor(
        patientId: _patientId,
        userId: _doctorId!,
        grantType: _grantType,
        consentId: _consentId,
      );
      if (mounted) setState(() => _info = 'Access granted to the doctor.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paperless consent')),
      body: _loading
          ? const LoadingView(label: 'Loading consent')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'I consent to the processing of my personal health data for medical purposes by authorised healthcare providers.',
                ),
                if (_info != null) Text(_info!),
                if (_error != null) Text(_error!),
                const SizedBox(height: 8),
                Text(_accepted ? 'Consent is on file.' : 'No consent is on file.'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _save(true),
                  child: const Text('I agree'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _save(false),
                  child: const Text('Withdraw consent'),
                ),
                const SizedBox(height: 20),
                Text('Grant a doctor', style: Theme.of(context).textTheme.titleMedium),
                const Text('Permanent, 30 days, or a one-time view.'),
                const SizedBox(height: 8),
                if (_doctors.isEmpty)
                  const Text('No doctors were listed for the selected clinic.')
                else
                  DropdownButtonFormField<String>(
                    initialValue: _doctorId,
                    decoration: const InputDecoration(labelText: 'Doctor'),
                    items: [
                      for (final doctor in _doctors)
                        DropdownMenuItem(
                          value: firstString(doctor, ['userId', 'id']),
                          child: Text(firstString(doctor, ['fullName', 'name'])),
                        ),
                    ],
                    onChanged: (value) => setState(() => _doctorId = value),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _grantType,
                  decoration: const InputDecoration(labelText: 'Grant type'),
                  items: const [
                    DropdownMenuItem(value: 'PERMANENT', child: Text('Permanent until revoked')),
                    DropdownMenuItem(value: 'TEMPORARY', child: Text('Temporary (30 days)')),
                    DropdownMenuItem(value: 'ONE_TIME', child: Text('One-time view')),
                  ],
                  onChanged: (value) => setState(() => _grantType = value ?? 'PERMANENT'),
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: _grant, child: const Text('Grant access')),
              ],
            ),
    );
  }
}
