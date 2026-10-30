import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/widgets/account_menu.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/status_views.dart';
import '../appointments/appointment_models.dart';
import '../appointments/appointments_repository.dart';
import '../care/care_repository.dart';
import 'patient_dashboard.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loading = true;
  DashboardData _data = const DashboardData();

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final care = ref.read(careRepositoryProvider);
    final visits = ref.read(appointmentsRepositoryProvider);
    String? error;
    Map<String, dynamic> profile = {};
    List<Appointment> appointments = [];
    List<Map<String, dynamic>> clinics = [];
    List<Map<String, dynamic>> vitals = [];
    bool? consent;
    try {
      profile = await care.profile();
    } on ApiException catch (err) {
      error = err.message;
    } catch (_) {}
    try {
      appointments = await visits.mine();
    } catch (_) {}
    try {
      clinics = await care.clinics();
    } catch (_) {}
    try {
      vitals = await care.vitals();
    } catch (_) {}
    final patientId = firstString(profile, ['id', 'patientId']);
    if (patientId.isNotEmpty) {
      try {
        consent = asBool((await care.consentCheck(patientId))['accepted']);
      } catch (_) {}
    }
    var clinicName = firstString(profile, ['tenantName', 'clinicName']);
    if (clinicName.isEmpty && clinics.isNotEmpty) {
      final tenantId = firstString(profile, ['tenantId']);
      final pick = clinics.firstWhere(
        (c) => asBool(c['selected']) || asBool(c['current']) || (tenantId.isNotEmpty && firstString(c, ['id', 'tenantId']) == tenantId),
        orElse: () => clinics.first,
      );
      clinicName = firstString(pick, ['name', 'clinicName', 'subdomain']);
    }
    bool connected = false;
    try {
      connected = ref.read(realtimeServiceProvider).connected;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = DashboardData(
        profile: profile,
        appointments: appointments,
        vitals: vitals,
        clinicName: clinicName,
        connected: connected,
        consentAccepted: consent,
        error: error,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const DigimedLogo(size: 30, subtitle: 'Patient'), actions: const [AccountMenu()]),
      drawer: PatientDrawer(clinicName: _data.clinicName),
      body: _loading
          ? const LoadingView(label: 'Loading your care')
          : PatientDashboardView(data: _data, now: DateTime.now(), onRefresh: _load),
    );
  }
}
