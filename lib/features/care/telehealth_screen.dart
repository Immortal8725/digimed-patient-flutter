import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'care_repository.dart';
import 'video_room.dart';

bool videoConsentComplete(Map<String, dynamic> consent) {
  final patient = firstString(consent, ['patientName']);
  final doctor = firstString(consent, ['doctorName']);
  final practice = firstString(consent, ['practiceNumber', 'bhfPracticeNumber']);
  final suitable = asBool(consent['suitableForVideo']);
  return patient.isNotEmpty &&
      doctor.isNotEmpty &&
      practice.isNotEmpty &&
      suitable &&
      !_placeholder(patient) &&
      !_placeholder(doctor);
}

bool _placeholder(String value) {
  return RegExp(r'^(patient|doctor)\s*#', caseSensitive: false).hasMatch(value);
}

class TelehealthScreen extends ConsumerStatefulWidget {
  const TelehealthScreen({super.key, required this.appointmentId, this.roomCode});

  final String appointmentId;
  final String? roomCode;

  @override
  ConsumerState<TelehealthScreen> createState() => _TelehealthScreenState();
}

class _TelehealthScreenState extends ConsumerState<TelehealthScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _suitable = false;
  String? _error;
  String? _info;
  Map<String, dynamic> _consent = {};
  Map<String, dynamic> _session = {};

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
      final care = ref.read(careRepositoryProvider);
      if (widget.appointmentId.isNotEmpty) {
        _consent = await care.videoConsent(widget.appointmentId);
        _suitable = asBool(_consent['suitableForVideo']);
      }
      if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
        _session = await care.room(widget.roomCode!);
        final linked = firstString(_session, ['appointmentId']);
        if (linked.isNotEmpty && _consent.isEmpty) {
          _consent = await care.videoConsent(linked);
          _suitable = asBool(_consent['suitableForVideo']);
        }
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

  Future<void> _record() async {
    setState(() => _busy = true);
    try {
      _consent = await ref.read(careRepositoryProvider).recordVideoSuitability(
        appointmentId: widget.appointmentId,
        suitable: _suitable,
      );
      if (!mounted) return;
      setState(() => _info = videoConsentComplete(_consent)
          ? 'Video consent recorded. You can start when you are ready.'
          : 'Saved. The visit stays closed until the patient, doctor, practice number, and suitability are all on the clinic record.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    if (!videoConsentComplete(_consent)) {
      setState(
        () => _info =
            'Record video consent first. The patient, the doctor, the practice number, and suitability are required.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      _session = await ref.read(careRepositoryProvider).startVideoSession(widget.appointmentId);
      final url = firstString(_session, ['joinUrl', 'url', 'roomUrl']);
      final sessionId = firstString(_session, ['id', 'sessionId']);
      if (sessionId.isEmpty && url.startsWith('http')) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      setState(
        () => _info = sessionId.isEmpty
            ? 'Video session opened with the clinic.'
            : 'Video room is ready. Start the consultation when you are in a private place.',
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (firstString(_consent, ['patientName']).isEmpty) 'patient name',
      if (firstString(_consent, ['doctorName']).isEmpty) 'doctor name',
      if (firstString(_consent, ['practiceNumber', 'bhfPracticeNumber']).isEmpty)
        'practice number',
      if (!asBool(_consent['suitableForVideo'])) 'a decision that this case is suitable for video',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Video visit')),
      body: _loading
          ? const LoadingView(label: 'Loading video consent')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Names and the practice number come from the clinic record. The visit stays closed until the patient, the doctor, the practice number, and suitability for video are all recorded.',
                ),
                if (_info != null) Text(_info!),
                if (_error != null) Text(_error!),
                const SizedBox(height: 12),
                Text('Patient: ${firstString(_consent, ['patientName']).isEmpty ? 'Not on the record' : firstString(_consent, ['patientName'])}'),
                Text('Doctor: ${firstString(_consent, ['doctorName']).isEmpty ? 'Not on the record' : firstString(_consent, ['doctorName'])}'),
                Text('Practice number: ${firstString(_consent, ['practiceNumber', 'bhfPracticeNumber']).isEmpty ? 'Not on the record' : firstString(_consent, ['practiceNumber', 'bhfPracticeNumber'])}'),
                if (missing.isNotEmpty) Text('Still needed: ${missing.join(', ')}.'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _suitable,
                  onChanged: (value) => setState(() => _suitable = value ?? false),
                  title: const Text('This case is suitable for a video visit'),
                ),
                FilledButton(
                  onPressed: _busy || widget.appointmentId.isEmpty ? null : _record,
                  child: Text(_busy ? 'Saving...' : 'Record video suitability'),
                ),
                const SizedBox(height: 8),
                if (firstString(_session, ['id', 'sessionId']).isEmpty)
                  FilledButton.tonal(
                    onPressed: _busy || !videoConsentComplete(_consent) ? null : _start,
                    child: const Text('Open video room'),
                  ),
                if (firstString(_session, ['id', 'sessionId']).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  VideoRoom(
                    sessionId: firstString(_session, ['id', 'sessionId']),
                    consentReady: videoConsentComplete(_consent),
                    roomStatus: firstString(_session, ['status']),
                    roomLabel: firstString(_session, ['roomCode', 'code']).isEmpty
                        ? 'DigiMed telehealth'
                        : 'Room ${firstString(_session, ['roomCode', 'code'])}',
                  ),
                ],
              ],
            ),
    );
  }
}
