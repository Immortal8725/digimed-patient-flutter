import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/brand_logo.dart';
import '../appointments/appointment_models.dart';
import '../appointments/appointments_repository.dart';
import '../care/care_repository.dart';
import '../../core/widgets/account_menu.dart';
import '../../core/widgets/status_views.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profile = {};
  List<Appointment> _appointments = [];
  List<Map<String, dynamic>> _clinics = [];
  List<Map<String, dynamic>> _vitals = [];
  List<Map<String, dynamic>> _todos = [];
  Map<String, dynamic> _estimate = {};
  int _dosesToday = 0;

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
    final care = ref.read(careRepositoryProvider);
    final visits = ref.read(appointmentsRepositoryProvider);
    String? error;
    try {
      _profile = await care.profile();
    } on ApiException catch (err) {
      error = err.message;
    }
    try {
      _appointments = await visits.mine();
    } catch (_) {}
    try {
      _clinics = await care.clinics();
    } catch (_) {}
    try {
      _vitals = await care.vitals();
    } catch (_) {
      _vitals = [];
    }
    try {
      _todos = await care.todos();
    } catch (_) {
      _todos = [];
    }
    try {
      _estimate = await care.copayEstimate();
    } catch (_) {
      _estimate = {};
    }
    try {
      _dosesToday = (await care.dosesToday()).length;
    } catch (_) {
      _dosesToday = 0;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final next = _appointments.where((item) => item.isUpcomingOn(today)).toList()
      ..sort((a, b) => '${a.date}${a.startTime}'.compareTo('${b.date}${b.startTime}'));
    final name = firstString(_profile, ['fullName', 'name']);
    return Scaffold(
      appBar: AppBar(title: const DigimedLogo(size: 30, subtitle: 'Home'), actions: const [AccountMenu()]),
      body: _loading
          ? const LoadingView(label: 'Loading your care')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    name.isEmpty ? 'Welcome back' : 'Hello, $name',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text('Your clinics, next visit, and anything the clinic has sent.'),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Profile',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medical aid: ${firstString(_profile, ['medicalAid', 'medicalAidProvider']).isEmpty ? 'Not on file' : firstString(_profile, ['medicalAid', 'medicalAidProvider'])}'),
                        if (firstString(_profile, ['planClass', 'planName']).isNotEmpty)
                          Text('Card class: ${firstString(_profile, ['planClass', 'planName'])}'),
                        if (firstString(_profile, ['coverageLevel']).isNotEmpty)
                          Text('Cover: ${firstString(_profile, ['coverageLevel'])}'),
                        Text('Phone: ${firstString(_profile, ['phone']).isEmpty ? 'Not on file' : firstString(_profile, ['phone'])}'),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => context.push('/profile'),
                            child: const Text('Update contact details'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Clinics',
                    child: _clinics.isEmpty
                        ? const Text('No clinics are linked to this account yet.')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final clinic in _clinics)
                                Text(firstString(clinic, ['name', 'clinicName', 'subdomain'])),
                              TextButton(
                                onPressed: () => context.push('/clinics'),
                                child: const Text('Switch clinic'),
                              ),
                            ],
                          ),
                  ),
                  if (_estimate.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'Cover',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstString(_estimate, ['explanation']).isEmpty
                                ? (asBool(_estimate['requiresCopay'])
                                      ? 'A co-payment is required for this visit.'
                                      : 'No co-payment was estimated.')
                                : firstString(_estimate, ['explanation']),
                          ),
                          if (asBool(_estimate['requiresCopay']))
                            TextButton(
                              onPressed: () => context.go('/appointments'),
                              child: const Text('Pay or prepare co-pay'),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (_dosesToday > 0) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'Today\'s doses',
                      child: TextButton(
                        onPressed: () => context.push('/medications'),
                        child: Text('$_dosesToday due. Taken, snooze, or skip.'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Next appointment',
                    child: next.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('No upcoming visit is booked.'),
                              TextButton(
                                onPressed: () => context.go('/find-care'),
                                child: const Text('Find care'),
                              ),
                            ],
                          )
                        : ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(next.first.doctorName.isEmpty ? 'Visit' : next.first.doctorName),
                            subtitle: Text(
                              '${next.first.date} ${next.first.startTime} ${next.first.clinicName}'.trim(),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/appointments/${next.first.id}'),
                          ),
                  ),
                  if (_vitals.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'Vitals',
                      subtitle: 'Readings returned by your clinic',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final vital in _vitals.take(6))
                            Text(_vitalLine(vital)),
                        ],
                      ),
                    ),
                  ],
                  if (_todos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'Tasks from your clinic',
                      child: Column(
                        children: [
                          for (final todo in _todos)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                asBool(todo['done'])
                                    ? Icons.check_circle_outline
                                    : Icons.radio_button_unchecked,
                              ),
                              title: Text(
                                firstString(todo, ['label', 'title', 'text']).isEmpty
                                    ? 'Task'
                                    : firstString(todo, ['label', 'title', 'text']),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Book appointment'),
                        onPressed: () => context.push('/book'),
                      ),
                      ActionChip(
                        label: const Text('Mission control'),
                        onPressed: () => context.push('/mission'),
                      ),
                      ActionChip(
                        label: const Text('Intake'),
                        onPressed: () => context.push('/intake'),
                      ),
                      ActionChip(
                        label: const Text('Medications'),
                        onPressed: () => context.push('/medications'),
                      ),
                      ActionChip(
                        label: const Text('Notices'),
                        onPressed: () => context.push('/notifications'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String _vitalLine(Map<String, dynamic> vital) {
    final type = firstString(vital, ['type', 'name', 'label', 'vitalType']);
    final value = firstString(vital, ['value', 'reading']);
    final unit = firstString(vital, ['unit']);
    final when = firstString(vital, ['recordedAt', 'takenAt', 'createdAt']);
    return [type, value, unit, when].where((part) => part.isNotEmpty).join(' ');
  }
}
