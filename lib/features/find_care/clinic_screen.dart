import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../reviews/practice_reviews_widgets.dart';
import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'find_care_repository.dart';

class ClinicScreen extends ConsumerStatefulWidget {
  const ClinicScreen({super.key, required this.subdomain});

  final String subdomain;

  @override
  ConsumerState<ClinicScreen> createState() => _ClinicScreenState();
}

class _ClinicScreenState extends ConsumerState<ClinicScreen> {
  bool _loading = true;
  String? _error;
  String? _info;
  Map<String, dynamic> _clinic = {};
  List<Map<String, dynamic>> _doctors = [];
  String _date = '';
  final Map<String, List<String>> _slots = {};

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
    try {
      final repo = ref.read(findCareRepositoryProvider);
      final clinic = await repo.clinicBySubdomain(widget.subdomain);
      final tenantId = firstString(clinic, ['id', 'tenantId']);
      final doctors = tenantId.isEmpty ? <Map<String, dynamic>>[] : await repo.doctors(tenantId);
      if (!mounted) return;
      setState(() {
        _clinic = clinic;
        _doctors = doctors;
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

  Future<void> _loadSlots(String doctorId) async {
    try {
      final slots = await ref.read(findCareRepositoryProvider).slots(doctorId, _date);
      if (!mounted) return;
      setState(() => _slots[doctorId] = slots);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _book(String doctorId, String start) async {
    if (!bookingEnabled(_clinic)) {
      setState(() => _error = 'Online booking is currently disabled for this clinic.');
      return;
    }
    var accepted = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Check your booking'),
          content: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: accepted,
            onChanged: (value) => setLocal(() => accepted = value ?? false),
            title: const Text('I accept the data-processing and privacy notice (POPIA).'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
            FilledButton(onPressed: accepted ? () => Navigator.pop(context, true) : null, child: const Text('Book')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final receipt = await ref
          .read(findCareRepositoryProvider)
          .book(doctorId: doctorId, date: _date, startTime: start.length >= 5 ? start.substring(0, 5) : start);
      if (!mounted) return;
      setState(() => _info = 'Visit booked.\n${receipt.describe()}');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = firstString(_clinic, ['name']);
    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? 'Clinic' : name)),
      body: _loading
          ? const LoadingView(label: 'Loading clinic')
          : _error != null && _clinic.isEmpty
          ? ErrorView(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(firstString(_clinic, ['city', 'province', 'address'])),
                if (!bookingEnabled(_clinic)) const Text('Online booking is currently disabled for this clinic.'),
                if (_info != null) Text(_info!),
                if (_error != null) Text(_error!),
                const SizedBox(height: 8),
                if (firstString(_clinic, ['id', 'tenantId']).isNotEmpty) ...[
                  PracticeReviewsSection(tenantId: firstString(_clinic, ['id', 'tenantId'])),
                  const SizedBox(height: 8),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(_date),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 180)),
                      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _date = picked.toIso8601String().substring(0, 10);
                        _slots.clear();
                      });
                    }
                  },
                ),
                if (_doctors.isEmpty) const HeartEmptyBox('No doctors were listed for this clinic.'),
                for (final doctor in _doctors) _doctorTile(doctor),
                TextButton(onPressed: () => context.go('/appointments'), child: const Text('See my appointments')),
              ],
            ),
    );
  }

  Widget _doctorTile(Map<String, dynamic> doctor) {
    final id = firstString(doctor, ['id', 'userId', 'doctorId']);
    final slots = _slots[id] ?? const <String>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(firstString(doctor, ['fullName', 'name'])),
            Text(firstString(doctor, ['specialty'])),
            TextButton(onPressed: id.isEmpty ? null : () => _loadSlots(id), child: const Text('Show open slots')),
            Wrap(
              spacing: 8,
              children: [for (final slot in slots) OutlinedButton(onPressed: () => _book(id, slot), child: Text(slot))],
            ),
          ],
        ),
      ),
    );
  }
}
