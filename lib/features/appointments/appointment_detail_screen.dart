import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import '../find_care/find_care_repository.dart';
import 'appointment_models.dart';
import 'appointments_repository.dart';
import '../reviews/rate_visit_screen.dart';
import '../reviews/reviews_repository.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _canRate = false;
  String? _error;
  String? _info;
  Appointment? _appointment;
  String? _invoiceId;

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
      final rows = await ref.read(appointmentsRepositoryProvider).mine(detailed: true);
      Appointment? match;
      for (final row in rows) {
        if (row.id == widget.id) match = row;
      }
      if (!mounted) return;
      setState(() {
        _appointment = match;
        _loading = false;
        if (match == null) _error = 'That appointment was not found on your account.';
      });
      if (match != null && match.status.toUpperCase() == 'COMPLETED') {
        try {
          final open = await ref.read(reviewsRepositoryProvider).eligible();
          if (mounted) setState(() => _canRate = open.any((v) => v.appointmentId == widget.id));
        } on ApiException {
          // Rating is optional; ignore lookup errors.
        }
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() => _info = success);
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this visit?'),
        content: const Text('You can book again from Find care.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (yes == true) {
      await _run(
        () => ref.read(appointmentsRepositoryProvider).cancel(widget.id),
        'Appointment cancelled.',
      );
    }
  }

  Future<void> _reschedule() async {
    final visit = _appointment;
    if (visit == null) return;
    var date = visit.date.isEmpty
        ? DateTime.now().toIso8601String().substring(0, 10)
        : visit.date;
    var start = visit.startTime;
    final slots = <String>[];
    if (visit.doctorId.isNotEmpty) {
      try {
        slots.addAll(
          await ref.read(findCareRepositoryProvider).slots(visit.doctorId, date),
        );
      } catch (_) {}
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Reschedule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Date'),
                subtitle: Text(date),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                    initialDate: DateTime.tryParse(date) ?? DateTime.now(),
                  );
                  if (picked != null) {
                    date = picked.toIso8601String().substring(0, 10);
                    setLocal(() {});
                  }
                },
              ),
              if (slots.isEmpty)
                TextFormField(
                  initialValue: start,
                  decoration: const InputDecoration(labelText: 'Start time (HH:mm)'),
                  onChanged: (value) => start = value,
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: slots.contains(start) ? start : slots.first,
                  items: [
                    for (final slot in slots)
                      DropdownMenuItem(value: slot, child: Text(slot)),
                  ],
                  onChanged: (value) => start = value ?? start,
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved == true && start.trim().isNotEmpty) {
      await _run(
        () => ref.read(appointmentsRepositoryProvider).reschedule(
          id: widget.id,
          date: date,
          startTime: start.trim(),
        ),
        'Appointment rescheduled.',
      );
    }
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final attempt = await ref
          .read(appointmentsRepositoryProvider)
          .startCopay(widget.id);
      if (!mounted) return;
      _invoiceId = attempt.invoiceId;
      if (attempt.checkoutUrl != null) {
        final opened = await launchUrl(
          Uri.parse(attempt.checkoutUrl!),
          mode: LaunchMode.externalApplication,
        );
        setState(() {
          _info = opened
              ? 'Paystack checkout opened. Come back here after you pay to confirm.'
              : 'The checkout link could not be opened.';
        });
      } else {
        setState(() => _info = attempt.message);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPay() async {
    final invoiceId = _invoiceId;
    if (invoiceId == null || invoiceId.isEmpty) {
      setState(() => _info = 'Start the co-pay before confirming a payment.');
      return;
    }
    final reference = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payment'),
        content: TextField(
          controller: reference,
          decoration: const InputDecoration(
            labelText: 'Paystack reference (if you have one)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final message = await ref.read(appointmentsRepositoryProvider).confirmCopay(
        invoiceId,
        reference: reference.text,
      );
      if (mounted) setState(() => _info = message);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
    reference.dispose();
  }

  Widget _checkInButton(Appointment visit) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    switch (visit.checkInState(today)) {
      case 'already':
        final when = visit.checkedInAt.replaceFirst('T', ' ');
        final clock = when.length >= 16 ? when.substring(11, 16) : '';
        final waiting = visit.status.toUpperCase() == 'IN_PROGRESS'
            ? 'consult in progress'
            : 'waiting for your clinician';
        return Text(
          clock.isEmpty ? 'Checked in, $waiting.' : 'Checked in at $clock, $waiting.',
        );
      case 'closed':
        return const OutlinedButton(onPressed: null, child: Text('Check-in closed'));
      case 'open':
        return FilledButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => ref.read(appointmentsRepositoryProvider).checkIn(widget.id),
                  'You are checked in. The clinic can see you are here.',
                ),
          child: Text(_busy ? 'Checking in...' : 'I am here, check in'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = _appointment;
    return Scaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: _loading
          ? const LoadingView(label: 'Loading appointment')
          : visit == null
          ? ErrorView(message: _error ?? 'Appointment not found', onRetry: _load)
          : HeartFormPanel(
              title: 'Visit details',
              padding: const EdgeInsets.all(16),
              children: [
                Text(visit.doctorName.isEmpty ? 'Visit' : visit.doctorName, style: Theme.of(context).textTheme.titleLarge),
                Text(visit.clinicName),
                Text('${visit.date} ${visit.startTime} to ${visit.endTime}'.trim()),
                Text('Status: ${visit.status}'),
                Text('Type: ${visit.modality.isEmpty ? 'In person' : visit.modality}'),
                if (visit.arriveByTime.isNotEmpty)
                  Text(
                    'Please arrive by ${visit.arriveByTime} (${visit.arriveMinutesEarly} min early)',
                  ),
                if (visit.intakeHint.isNotEmpty) Text(visit.intakeHint),
                if (_info != null) ...[const SizedBox(height: 8), Text(_info!)],
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                if (!visit.isCancelled) ...[
                  _checkInButton(visit),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _busy ? null : _reschedule, child: const Text('Reschedule')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel visit')),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.push('/appointments/${visit.id}/chat'),
                    child: const Text('Chat with the clinic'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _busy ? null : _pay, child: const Text('Pay co-pay')),
                  TextButton(onPressed: _busy ? null : _confirmPay, child: const Text('Confirm Paystack payment')),
                  if (visit.isVideo || visit.modality.toUpperCase().contains('VIDEO'))
                    FilledButton.tonal(
                      onPressed: () => context.push('/telehealth/${visit.id}'),
                      child: const Text('Video visit'),
                    ),
                ],
                if (visit.status.toUpperCase() == 'COMPLETED' && _canRate) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      final done = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => RateVisitScreen(appointmentId: visit.id, practiceName: visit.clinicName),
                        ),
                      );
                      if (done == true && mounted) setState(() => _canRate = false);
                    },
                    child: const Text('Rate your visit'),
                  ),
                ],
                const SizedBox(height: 8),
                if (visit.intakeCompleted && !visit.intakeNeeded)
                  Text(visit.intakeHint)
                else
                  TextButton(
                    onPressed: () => context.push(
                      '/intake?appointmentId=${visit.id}&tenantId=${visit.tenantId}',
                    ),
                    child: Text(visit.intakeButtonLabel),
                  ),
              ],
            ),
    );
  }
}
