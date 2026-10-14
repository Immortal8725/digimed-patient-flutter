import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import '../care/care_repository.dart';
import 'appointment_models.dart';
import 'appointments_repository.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  String? _estimate;
  bool _needsCopay = false;
  List<Appointment> _rows = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      try {
        final estimate = await ref.read(careRepositoryProvider).copayEstimate();
        _needsCopay = asBool(estimate['requiresCopay']);
        _estimate = firstString(estimate, ['explanation']);
      } catch (_) {
        _needsCopay = false;
        _estimate = null;
      }
      final rows = await ref.read(appointmentsRepositoryProvider).mine(detailed: true);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } on ApiException catch (error) {
      try {
        final rows = await ref.read(appointmentsRepositoryProvider).mine();
        if (!mounted) return;
        setState(() {
          _rows = rows;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final upcoming = _rows.where((row) => row.isUpcomingOn(today)).toList();
    final cancelled = _rows.where((row) => row.isCancelled).toList();
    final past = _rows.where((row) => !row.isCancelled && !row.isUpcomingOn(today)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _loading
          ? const LoadingView(label: 'Loading appointments')
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : Column(
              children: [
                if (_needsCopay || (_estimate != null && _estimate!.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      _estimate == null || _estimate!.isEmpty
                          ? 'A co-payment is required. Open a visit to pay.'
                          : _estimate!,
                    ),
                  ),
                Expanded(
                  child: TabBarView(
              controller: _tabs,
              children: [
                _list(upcoming, 'No upcoming appointments', 'Book a visit, then cancel or reschedule if plans change.'),
                _list(past, 'No past appointments', 'Completed visits will show here.'),
                _list(cancelled, 'No cancelled appointments', 'Cancelled bookings stay here for your records.'),
              ],
                ),
              ),
            ],
            ),
    );
  }

  Widget _list(List<Appointment> rows, String title, String detail) {
    if (rows.isEmpty) {
      return EmptyView(
        title: title,
        detail: detail,
        action: FilledButton(
          onPressed: () => context.go('/find-care'),
          child: const Text('Find care'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          for (final row in rows)
            ListTile(
              title: Text(row.doctorName.isEmpty ? 'Appointment' : row.doctorName),
              subtitle: Text(
                '${row.date} ${row.startTime} ${row.clinicName} ${row.status}'.trim(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/appointments/${row.id}'),
            ),
        ],
      ),
    );
  }
}
