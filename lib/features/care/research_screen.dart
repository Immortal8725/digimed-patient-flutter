import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'care_repository.dart';

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  final _fields = <String, TextEditingController>{};
  bool _loading = true;
  bool _visible = false;
  String? _error;
  String? _info;
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _enrolments = [];

  static const _keys = [
    'displayName',
    'city',
    'province',
    'ageBand',
    'sexAtBirth',
    'chronicConditions',
    'medications',
    'allergies',
    'smokingStatus',
    'interestTags',
    'willingTravelKm',
    'availableWeekdays',
  ];

  @override
  void initState() {
    super.initState();
    for (final key in _keys) {
      _fields[key] = TextEditingController();
    }
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(careRepositoryProvider);
    try {
      final profile = await repo.volunteer();
      for (final key in _keys) {
        _fields[key]!.text = str(profile[key]);
      }
      _visible = asBool(profile['visible']);
    } catch (_) {}
    try {
      _offers = await repo.offers();
    } catch (_) {}
    try {
      _enrolments = await repo.enrolments();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Map<String, dynamic> _body() {
    final body = <String, dynamic>{
      for (final key in _keys)
        key: key == 'willingTravelKm'
            ? (_fields[key]!.text.trim().isEmpty ? null : num.tryParse(_fields[key]!.text.trim()))
            : _fields[key]!.text.trim(),
      'visible': _visible,
    };
    return body;
  }

  Future<void> _save() async {
    try {
      await ref.read(careRepositoryProvider).saveVolunteer(_body());
      if (mounted) {
        setState(() => _info = 'Volunteer profile saved. Research sites can find you if you are visible.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _sign(Map<String, dynamic> enrolment) async {
    final text = firstString(enrolment, ['consentText', 'studyConsentText']).isEmpty
        ? 'I consent to participate in this research study. I understand I may withdraw at any time.'
        : firstString(enrolment, ['consentText', 'studyConsentText']);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('eConsent preview'),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I agree, sign eConsent')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(careRepositoryProvider).signEconsent(firstString(enrolment, ['id', 'participantId']));
      if (!mounted) return;
      setState(() => _info = 'eConsent recorded.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _offer(String id, bool accept) async {
    try {
      final repo = ref.read(careRepositoryProvider);
      if (accept) {
        await repo.acceptOffer(id);
      } else {
        await repo.declineOffer(id);
      }
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My research')),
      body: _loading
          ? const LoadingView(label: 'Loading research')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Opt-in profile, offers, and eConsent. Answers are self-declared (POPIA).'),
                if (_info != null) Text(_info!),
                if (_error != null) Text(_error!),
                const SizedBox(height: 8),
                for (final key in _keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _fields[key],
                      decoration: InputDecoration(labelText: _label(key)),
                    ),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _visible,
                  onChanged: (value) => setState(() => _visible = value ?? false),
                  title: const Text('Visible to research sites'),
                ),
                FilledButton(onPressed: _save, child: const Text('Save profile')),
                const SizedBox(height: 16),
                HeartHeader('Offers inbox'),
                if (_offers.isEmpty) const HeartEmptyBox('No offers yet.'),
                for (final offer in _offers)
                  Card(
                    child: ListTile(
                      title: Text(
                        firstString(offer, ['studyTitle']).isEmpty ? 'Study' : firstString(offer, ['studyTitle']),
                      ),
                      subtitle: Text('${firstString(offer, ['message'])}\n${firstString(offer, ['status'])}'),
                      isThreeLine: true,
                      trailing: firstString(offer, ['status']).toUpperCase() == 'PENDING'
                          ? Wrap(
                              spacing: 4,
                              children: [
                                TextButton(
                                  onPressed: () => _offer(firstString(offer, ['id']), true),
                                  child: const Text('Accept'),
                                ),
                                TextButton(
                                  onPressed: () => _offer(firstString(offer, ['id']), false),
                                  child: const Text('Decline'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                const SizedBox(height: 12),
                HeartHeader('My enrolments'),
                const Text('Sign eConsent before study procedures.'),
                if (_enrolments.isEmpty) const HeartEmptyBox('No enrolments yet.'),
                for (final enrolment in _enrolments)
                  Card(
                    child: ListTile(
                      title: Text(firstString(enrolment, ['subjectCode'])),
                      subtitle: Text(
                        '${firstString(enrolment, ['studyTitle', 'studyId'])} ${firstString(enrolment, ['status'])}',
                      ),
                      trailing: TextButton(onPressed: () => _sign(enrolment), child: const Text('Sign eConsent')),
                    ),
                  ),
              ],
            ),
    );
  }

  String _label(String key) {
    return switch (key) {
      'displayName' => 'Display name',
      'ageBand' => 'Age band',
      'sexAtBirth' => 'Sex at birth',
      'chronicConditions' => 'Chronic conditions',
      'smokingStatus' => 'Smoking status',
      'interestTags' => 'Interest tags',
      'willingTravelKm' => 'Willing to travel (km)',
      'availableWeekdays' => 'Available weekdays',
      _ => key[0].toUpperCase() + key.substring(1),
    };
  }
}
