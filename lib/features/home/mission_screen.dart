import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import '../care/care_repository.dart';

class MissionScreen extends ConsumerStatefulWidget {
  const MissionScreen({super.key});

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

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
      final data = await ref.read(careRepositoryProvider).mission();
      if (!mounted) return;
      setState(() {
        _data = data;
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

  @override
  Widget build(BuildContext context) {
    final widgets = asMap(_data['widgets']);
    final next = asMap(widgets['myNextAppointment']);
    final checkIn = asMap(widgets['myCheckIn']);
    final offers = widgets['myResearchOffers'];
    final meds = widgets['myMedicationExpiries'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Mission Control'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const LoadingView(label: 'Loading mission control')
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const HeartHeader(
                  'Mission Control',
                  subtitle: 'Your visits, wait time, medicines, and research offers.',
                ),
                const SizedBox(height: 12),
                _tile(
                  'Next visit',
                  firstString(next, ['startTime']).isEmpty
                      ? 'None sent'
                      : '${firstString(next, ['appointmentDate', 'date'])} ${firstString(next, ['startTime'])}',
                  onTap: () => context.go('/appointments'),
                ),
                _tile('Checked in', asBool(checkIn['checkedIn']) ? 'Yes' : 'No'),
                _tile(
                  'Estimated wait (minutes)',
                  str(checkIn['estimatedWaitMinutes']).isEmpty
                      ? 'Not sent by the clinic'
                      : str(checkIn['estimatedWaitMinutes']),
                ),
                _tile(
                  'Research offers',
                  offers == null ? 'Not sent' : '${asList(offers).length}',
                  onTap: () => context.push('/research'),
                ),
                _tile(
                  'Medicines ending',
                  meds == null ? 'Not sent' : '${asList(meds).length}',
                  onTap: () => context.push('/medications'),
                ),
                const SizedBox(height: 8),
                HeartCta('Open intake', onPressed: () => context.push('/intake')),
              ],
            ),
    );
  }

  Widget _tile(String label, String value, {VoidCallback? onTap}) {
    return HeartTile(title: label, subtitle: value, icon: _missionIcons[label] ?? Icons.speed, onTap: onTap);
  }
}

const _missionIcons = <String, IconData>{
  'Next visit': Icons.event_outlined,
  'Checked in': Icons.how_to_reg_outlined,
  'Estimated wait (minutes)': Icons.timer_outlined,
  'Research offers': Icons.science_outlined,
  'Medicines ending': Icons.medication_outlined,
};
