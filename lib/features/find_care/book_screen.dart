import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_store.dart';
import '../../core/widgets/status_views.dart';
import '../appointments/appointment_models.dart';
import '../appointments/appointments_repository.dart';
import 'find_care_repository.dart';

class BookScreen extends ConsumerStatefulWidget {
  const BookScreen({super.key});

  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends ConsumerState<BookScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _info;
  String _tenantId = '';
  Map<String, dynamic> _tenant = {};
  List<Map<String, dynamic>> _doctors = [];
  Appointment? _existing;
  String _doctorId = '';
  String _date = '';
  String _modality = 'IN_PERSON';
  String _service = '';
  String _notes = '';
  String _start = '';
  String _end = '';
  bool _consent = false;
  List<String> _freeSlots = [];

  @override
  void initState() {
    super.initState();
    _date = DateTime.now().toIso8601String().substring(0, 10);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final tenantId = (await ref.read(tokenStoreProvider).read('tenantId') ?? '').trim();
    if (tenantId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Choose a clinic on this account before booking.';
      });
      return;
    }
    try {
      final repo = ref.read(findCareRepositoryProvider);
      final tenant = await repo.tenant(tenantId);
      final doctors = await repo.doctors(tenantId);
      Appointment? existing;
      try {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final visits = await ref.read(appointmentsRepositoryProvider).mine(detailed: true);
        for (final visit in visits) {
          if (visit.tenantId == tenantId && visit.isUpcomingOn(today)) {
            existing = visit;
            break;
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _tenantId = tenantId;
        _tenant = tenant;
        _doctors = doctors;
        _existing = existing;
        _doctorId = doctors.length == 1 ? firstString(doctors.first, ['id', 'userId', 'doctorId']) : '';
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

  List<ClinicSlot> get _hours {
    return clinicHourSlots(
      opening: firstString(_tenant, ['openingHour']),
      closing: firstString(_tenant, ['closingHour']),
      durationMinutes: asInt(_tenant['appointmentDuration']) ?? 30,
    );
  }

  Future<void> _refreshFreeSlots() async {
    if (_doctorId.isEmpty || _date.isEmpty) return;
    try {
      final slots = await ref.read(findCareRepositoryProvider).slots(_doctorId, _date);
      if (!mounted) return;
      setState(() => _freeSlots = slots);
    } catch (_) {
      if (mounted) setState(() => _freeSlots = []);
    }
  }

  Future<void> _openPrivacy() async {
    final uri = Uri.parse('https://www.digimed-connect.co.za/legal/privacy-cookie');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _review() async {
    if (!_consent) {
      setState(() => _error = 'You must accept the data-processing and privacy notice to book.');
      return;
    }
    if (_doctorId.isEmpty || _date.isEmpty || _start.isEmpty || _end.isEmpty) {
      setState(() => _error = 'Choose a doctor, a date, and a time.');
      return;
    }
    final doctor = _doctors.cast<Map<String, dynamic>?>().firstWhere(
      (row) => firstString(row!, ['id', 'userId', 'doctorId']) == _doctorId,
      orElse: () => null,
    );
    final name = doctor == null ? 'Doctor' : firstString(doctor, ['fullName', 'name']);
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review booking'),
        content: Text(
          '${firstString(_tenant, ['name'])}\n$name\n$_date\n$_start - $_end\n${_modality == 'VIDEO' ? 'Video' : 'In person'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm booking')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await ref
          .read(findCareRepositoryProvider)
          .book(
            doctorId: _doctorId,
            date: _date,
            startTime: _start,
            endTime: _end,
            modality: _modality,
            notes: _notes,
            preferredService: _service,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _info = 'Visit booked.\n${receipt.describe()}';
        _existing = Appointment(
          id: '',
          status: 'BOOKED',
          date: _date,
          startTime: _start,
          tenantId: _tenantId,
          raw: const {},
        );
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = bookingEnabled(_tenant);
    final blocked = _existing != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: _loading
          ? const LoadingView(label: 'Loading booking portal')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  firstString(_tenant, ['name']).isEmpty ? 'Booking portal' : firstString(_tenant, ['name']),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  [
                    firstString(_tenant, ['address']),
                    firstString(_tenant, ['city']),
                    firstString(_tenant, ['phone']),
                  ].where((part) => part.isNotEmpty).join(', '),
                ),
                if (!open)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Online booking is currently disabled for this clinic.'),
                  ),
                if (blocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'You already have a visit booked here'
                      '${_existing!.date.isEmpty ? '' : ' on ${_existing!.date}'}'
                      '${_existing!.startTime.isEmpty ? '' : ' at ${_existing!.startTime}'}'
                      '. Cancel or reschedule that one instead of booking again.',
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  if (_tenantId.isEmpty)
                    TextButton(onPressed: () => context.push('/clinics'), child: const Text('Choose a clinic')),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  Text(_info!),
                  TextButton(
                    onPressed: () => context.push('/intake?tenantId=$_tenantId'),
                    child: const Text('Complete intake'),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('doctor-$_doctorId-${_doctors.length}'),
                  initialValue: _doctorId,
                  decoration: const InputDecoration(labelText: 'Select doctor'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Select a doctor')),
                    for (final doctor in _doctors)
                      if (firstString(doctor, ['id', 'userId', 'doctorId']).isNotEmpty)
                        DropdownMenuItem(
                          value: firstString(doctor, ['id', 'userId', 'doctorId']),
                          child: Text(
                            '${firstString(doctor, ['fullName', 'name'])} ${firstString(doctor, ['specialty']).isEmpty ? 'General' : firstString(doctor, ['specialty'])}',
                          ),
                        ),
                  ],
                  onChanged: blocked || !open
                      ? null
                      : (value) {
                          setState(() => _doctorId = value ?? '');
                          _refreshFreeSlots();
                        },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Appointment date'),
                  subtitle: Text(_date),
                  onTap: blocked || !open
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 180)),
                            initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _date = picked.toIso8601String().substring(0, 10));
                            _refreshFreeSlots();
                          }
                        },
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('mode-$_modality'),
                  initialValue: _modality,
                  decoration: const InputDecoration(labelText: 'Visit type'),
                  items: const [
                    DropdownMenuItem(value: 'IN_PERSON', child: Text('In person')),
                    DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
                  ],
                  onChanged: blocked || !open ? null : (value) => setState(() => _modality = value ?? 'IN_PERSON'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Preferred service',
                    helperText: 'Optional. Sent with the booking.',
                  ),
                  onChanged: (value) => _service = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    helperText: 'Sent with the booking.',
                  ),
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) => _notes = value,
                ),
                const SizedBox(height: 16),
                HeartHeader('Open slots'),
                const SizedBox(height: 8),
                if (_freeSlots.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final slot in _freeSlots)
                        ChoiceChip(
                          label: Text(slot),
                          selected: _start == _hhmm(slot),
                          onSelected: blocked || !open
                              ? null
                              : (_) {
                                  final start = _hhmm(slot);
                                  setState(() {
                                    _start = start;
                                    _end = _endFor(start);
                                  });
                                },
                        ),
                    ],
                  )
                else if (_hours.isEmpty)
                  const HeartEmptyBox('No booking slots are configured yet. You can still type a time.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final slot in _hours)
                        ChoiceChip(
                          label: Text(slot.label),
                          selected: _start == slot.start && _end == slot.end,
                          onSelected: blocked || !open
                              ? null
                              : (_) => setState(() {
                                  _start = slot.start;
                                  _end = slot.end;
                                }),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text('Selected time: ${_start.isEmpty ? 'Not selected' : '$_start - $_end'}'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: (value) => setState(() => _consent = value ?? false),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('I accept the '),
                      InkWell(
                        onTap: _openPrivacy,
                        child: Text(
                          'data-processing and privacy notice',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text(' (POPIA).'),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _busy || blocked || !open ? null : _review,
                  child: Text(_busy ? 'Booking...' : 'Review booking'),
                ),
                if (blocked)
                  TextButton(onPressed: () => context.go('/appointments'), child: const Text('Cancel or reschedule')),
              ],
            ),
    );
  }

  String _hhmm(String value) => value.length >= 5 ? value.substring(0, 5) : value;

  String _endFor(String start) {
    final step = asInt(_tenant['appointmentDuration']) ?? 30;
    return clockOf(minutesOfDay(start) + step);
  }
}
