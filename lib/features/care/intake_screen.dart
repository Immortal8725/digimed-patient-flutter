import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import '../auth/auth_controller.dart';
import 'care_repository.dart';

class IntakeScreen extends ConsumerStatefulWidget {
  const IntakeScreen({super.key, this.appointmentId, this.tenantId});

  final String? appointmentId;
  final String? tenantId;

  @override
  ConsumerState<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends ConsumerState<IntakeScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _info;
  String _tenantId = '';
  String _mode = 'FIRST_VISIT';
  String _formId = '';
  String _patientId = '';
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _onFile = [];
  final Map<String, dynamic> _answers = {};

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
      final repo = ref.read(careRepositoryProvider);
      final profile = await repo.profile();
      _patientId = firstString(profile, ['id', 'patientId']);
      _tenantId = widget.tenantId?.isNotEmpty == true
          ? widget.tenantId!
          : firstString(profile, ['tenantId']);
      if (_tenantId.isEmpty) {
        final clinics = await repo.clinics();
        if (clinics.isNotEmpty) {
          _tenantId = firstString(clinics.first, ['id', 'tenantId']);
        }
      }
      if (_tenantId.isEmpty) {
        throw const ApiException('Select a clinic before completing intake.');
      }
      final form = await repo.intakeForm(
        tenantId: _tenantId,
        appointmentId: widget.appointmentId,
      );
      final formMap = asMap(form['form']);
      _formId = firstString(formMap.isEmpty ? form : formMap, ['id', 'formId']);
      _mode = firstString(form, ['mode']).isEmpty ? 'FIRST_VISIT' : firstString(form, ['mode']);
      _questions = asList(form['questions']).map(asMap).toList();
      _onFile = asList(form['onFile']).map(asMap).toList();
      final prefill = asMap(form['prefill']);
      _answers
        ..clear()
        ..addAll(prefill);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _info = firstString(form, ['message']);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final userId = ref.read(authControllerProvider).value?.userId ?? '';
      await ref.read(careRepositoryProvider).submitIntake(
        tenantId: _tenantId,
        patientId: _patientId,
        formId: _formId,
        userId: userId,
        mode: _mode,
        appointmentId: widget.appointmentId,
        answers: _answers,
      );
      if (!mounted) return;
      setState(() {
        _info = _mode == 'RETURN_VISIT'
            ? 'Visit update saved. Your clinic can see why you are here today.'
            : 'Intake submitted. Known details were saved where the clinic allows it.';
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intake form')),
      body: _loading
          ? const LoadingView(label: 'Loading intake')
          : _error != null && _questions.isEmpty
          ? ErrorView(message: _error!, onRetry: _load)
          : HeartFormPanel(
              title: 'Intake Form',
              padding: const EdgeInsets.all(16),
              children: [
                Text(_mode == 'RETURN_VISIT' ? 'Return visit' : 'First visit'),
                if (_info != null) Text(_info!),
                if (_error != null) Text(_error!),
                if (_onFile.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Already on file'),
                  for (final item in _onFile)
                    Text(firstString(item, ['label', 'question', 'value'])),
                ],
                const SizedBox(height: 8),
                for (final question in _questions) _field(question),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? 'Saving...' : 'Submit intake'),
                ),
                TextButton(
                  onPressed: () => context.go('/appointments'),
                  child: const Text('Back to appointments'),
                ),
              ],
            ),
    );
  }

  Widget _field(Map<String, dynamic> question) {
    final key = firstString(question, ['questionKey', 'key', 'id']);
    final label = firstString(question, ['label', 'question', 'text']);
    final type = firstString(question, ['fieldType', 'type']).toUpperCase();
    if (type == 'BOOLEAN') {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: asBool(_answers[key]),
        title: Text(label),
        onChanged: (value) => setState(() => _answers[key] = value ?? false),
      );
    }
    if (type == 'SELECT') {
      final options = _options(question['optionsJson'] ?? question['options']);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: str(_answers[key]).isEmpty ? '' : str(_answers[key]),
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: '', child: Text('Select')),
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) => setState(() => _answers[key] = value ?? ''),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: str(_answers[key]),
        maxLines: type == 'TEXTAREA' ? 3 : 1,
        keyboardType: type == 'NUMBER'
            ? TextInputType.number
            : type == 'DATE'
            ? TextInputType.datetime
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        onChanged: (value) => _answers[key] = value,
      ),
    );
  }

  List<String> _options(Object? raw) {
    if (raw is List) return raw.map(str).where((item) => item.isNotEmpty).toList();
    final text = str(raw);
    if (text.isEmpty) return const [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded.map(str).toList();
    } catch (_) {}
    return const [];
  }
}
