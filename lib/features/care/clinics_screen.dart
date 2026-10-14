import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import '../auth/auth_controller.dart';
import 'care_repository.dart';

class ClinicsScreen extends ConsumerStatefulWidget {
  const ClinicsScreen({super.key});

  @override
  ConsumerState<ClinicsScreen> createState() => _ClinicsScreenState();
}

class _ClinicsScreenState extends ConsumerState<ClinicsScreen> {
  bool _loading = true;
  String? _error;
  String? _info;
  List<Map<String, dynamic>> _clinics = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final clinics = await ref.read(careRepositoryProvider).clinics();
      if (!mounted) return;
      setState(() {
        _clinics = clinics;
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

  Future<void> _select(Map<String, dynamic> clinic) async {
    final id = firstString(clinic, ['id', 'tenantId']);
    try {
      final result = await ref.read(careRepositoryProvider).selectClinic(id);
      final token = firstString(result, ['token']);
      if (token.isNotEmpty) {
        await ref.read(authControllerProvider.notifier).rememberToken(
          token,
          tenantId: id,
        );
      }
      if (mounted) {
        setState(() => _info = 'Clinic set to ${firstString(clinic, ['name', 'clinicName'])}.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My clinics')),
      body: _loading
          ? const LoadingView(label: 'Loading clinics')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_info != null) Text(_info!),
                if (_error != null) Text(_error!),
                if (_clinics.isEmpty) const Text('No clinics are linked yet.'),
                for (final clinic in _clinics)
                  Card(
                    child: ListTile(
                      title: Text(firstString(clinic, ['name', 'clinicName'])),
                      subtitle: Text(firstString(clinic, ['city', 'province', 'subdomain'])),
                      trailing: const Text('Use'),
                      onTap: () => _select(clinic),
                    ),
                  ),
              ],
            ),
    );
  }
}
