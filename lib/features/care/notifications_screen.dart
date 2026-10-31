import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/widgets/status_views.dart';
import 'care_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _identity = TextEditingController();
  final _otp = TextEditingController();
  bool _loading = true;
  String? _error;
  String? _info;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _clinics = [];
  String? _tenantId;
  late final RealtimeService _realtime;

  @override
  void initState() {
    super.initState();
    _realtime = ref.read(realtimeServiceProvider);
    _realtime.addNotifyListener(_onNotify);
    Future.microtask(_load);
  }

  void _onNotify(dynamic _) {
    if (mounted) _load();
  }

  @override
  void dispose() {
    _realtime.removeNotifyListener(_onNotify);
    _identity.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(careRepositoryProvider);
      final appNotes = await repo.appNotifications();
      final paperless = await repo.paperlessNotifications();
      final clinics = await repo.clinics();
      if (!mounted) return;
      setState(() {
        _items = [...paperless.items, ...appNotes.items];
        _clinics = clinics;
        _tenantId ??= clinics.isEmpty ? null : firstString(clinics.first, ['id', 'tenantId']);
        _loading = false;
      });
      await repo.markNotificationsRead();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _decide(String id, bool approve) async {
    try {
      final repo = ref.read(careRepositoryProvider);
      if (approve) {
        await repo.approvePermission(id);
      } else {
        await repo.denyPermission(id);
      }
      if (!mounted) return;
      setState(() => _info = approve ? 'Access approved.' : 'Access denied.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _requestCode() async {
    if (_identity.text.trim().isEmpty || _tenantId == null) {
      setState(() => _error = 'Enter your ID, passport, or phone, and choose a clinic.');
      return;
    }
    try {
      final message = await ref
          .read(careRepositoryProvider)
          .requestLinkOtp(identity: _identity.text.trim(), tenantId: _tenantId!);
      if (mounted) setState(() => _info = message);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _link() async {
    if (_tenantId == null) return;
    try {
      await ref
          .read(careRepositoryProvider)
          .linkByIdentity(identity: _identity.text.trim(), otp: _otp.text.trim(), tenantId: _tenantId!);
      if (!mounted) return;
      setState(() => _info = 'Linked. You can approve requests for this record.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: _loading
          ? const LoadingView(label: 'Loading notices')
          : RefreshIndicator(
              onRefresh: _load,
              child: HeartFormPanel(
                title: 'Link Your Record',
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Text(_error!),
                  if (_info != null) Text(_info!),
                  const Text('Link a clinic record, then approve or deny access requests.'),
                  const SizedBox(height: 8),
                  if (_clinics.isEmpty)
                    const HeartEmptyBox('No linked clinic yet. You can still read notices.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _tenantId,
                      decoration: const InputDecoration(labelText: 'Clinic'),
                      items: [
                        for (final clinic in _clinics)
                          DropdownMenuItem(
                            value: firstString(clinic, ['id', 'tenantId']),
                            child: Text(firstString(clinic, ['name', 'clinicName'])),
                          ),
                      ],
                      onChanged: (value) => setState(() => _tenantId = value),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _identity,
                    decoration: const InputDecoration(labelText: 'SA ID, passport, or phone'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _requestCode, child: const Text('Request verification code')),
                  TextField(
                    controller: _otp,
                    decoration: const InputDecoration(labelText: 'Verification code'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _link, child: const Text('Link record')),
                  const SizedBox(height: 16),
                  if (_items.isEmpty) const HeartEmptyBox('No notices yet.'),
                  for (final item in _items) _tile(item),
                ],
              ),
            ),
    );
  }

  Widget _tile(Map<String, dynamic> item) {
    final permissionId = firstString(item, ['permissionId']);
    final type = firstString(item, ['type']).toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(firstString(item, ['title']).isEmpty ? 'Notice' : firstString(item, ['title'])),
            Text(firstString(item, ['message', 'body'])),
            if (type == 'PERMISSION' && permissionId.isNotEmpty)
              Row(
                children: [
                  FilledButton(onPressed: () => _decide(permissionId, true), child: const Text('Approve')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () => _decide(permissionId, false), child: const Text('Deny')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
