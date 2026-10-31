import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import 'auth_repository.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _otp = TextEditingController();

  List<Map<String, dynamic>> _clinics = [];
  List<String> _aids = [];
  String? _clinicId;
  String? _aid;
  bool _consent = false;
  bool _loading = true;
  bool _busy = false;
  bool _clinicsUnavailable = false;
  String? _error;
  String? _otpHint;
  String? _verificationToken;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _idNumber.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _clinicsUnavailable = false;
    });
    final api = ref.read(apiClientProvider);
    try {
      final clinicsData = await api.get('/public/clinics');
      final clinics = asList(clinicsData).map(asMap).where((clinic) {
        final name = firstString(clinic, ['name']);
        if (name.isEmpty) return false;
        final type = firstString(clinic, ['tenantType', 'tenant_type']).toUpperCase();
        return type.isEmpty || type == 'CLINIC' || type == 'RESEARCH';
      }).toList();
      if (!mounted) return;
      setState(() => _clinics = clinics);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clinics = [];
        _clinicsUnavailable = true;
        _error = error is ApiException ? error.message : 'Clinics could not be loaded. Try again in a moment.';
      });
    }
    try {
      final aidsData = await api.get('/public/medical-aids');
      final aids = asList(aidsData)
          .map((item) => item is String ? item : firstString(asMap(item), ['name']))
          .where((name) => name.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _aids = aids);
    } catch (_) {
      if (mounted) setState(() => _aids = []);
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _phoneRequiredOtp {
    final phone = _phone.text.trim();
    return phone.isNotEmpty && _verificationToken == null;
  }

  Future<void> _requestOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestOtp(phone: _phone.text.trim(), email: _email.text, clinicId: _clinicId, purpose: 'signup-phone');
      final preview = challenge.previewCode.isEmpty ? '' : ' Code: ${challenge.previewCode}.';
      setState(() {
        _otpHint =
            'A code was sent to ${challenge.maskedPhone.isEmpty ? 'your phone' : challenge.maskedPhone}.$preview';
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(authRepositoryProvider)
          .verifyOtp(phone: _phone.text.trim(), code: _otp.text, purpose: 'signup-phone');
      setState(() => _verificationToken = token);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final id = _idNumber.text.trim();
    if (!_consent) {
      setState(() => _error = 'Accept the data-processing and privacy notice to create an account.');
      return;
    }
    if (_clinicId == null) {
      setState(() => _error = 'Select the clinic you are joining.');
      return;
    }
    if (_name.text.trim().isEmpty ||
        _username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      setState(() => _error = 'Name, username, email, and password are required.');
      return;
    }
    if (id.isNotEmpty && !RegExp(r'^\d{13}$').hasMatch(id)) {
      setState(() => _error = 'SA ID numbers are 13 digits. Leave the field blank if you do not have one.');
      return;
    }
    if (_phoneRequiredOtp) {
      setState(() => _error = 'Verify your phone number with the SMS code before creating the account.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signup({
        'clinicId': int.tryParse(_clinicId!) ?? _clinicId,
        'fullName': _name.text.trim(),
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'phone': _phone.text.trim(),
        'medicalAid': _aid ?? '',
        'idNumber': id,
        'consentAccepted': true,
        if (_verificationToken != null) 'phoneVerificationToken': _verificationToken,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Patient account created. You can sign in now.')));
      context.go('/login');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create patient account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: HeartFormPanel(
                title: 'Your Details',
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Join a clinic on DigiMed Connect. You will use this account for visits, intake, and paperless care.',
                  ),
                  const SizedBox(height: 16),
                  if (_clinicsUnavailable)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Clinics could not be loaded. The list is still required before you can create an account.',
                        ),
                        TextButton(onPressed: _loading ? null : _load, child: const Text('Try again')),
                      ],
                    )
                  else if (_clinics.isEmpty)
                    const HeartEmptyBox('No clinics are open for signup right now.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _clinicId,
                      decoration: const InputDecoration(labelText: 'Clinic'),
                      items: [
                        for (final clinic in _clinics)
                          DropdownMenuItem(
                            value: firstString(clinic, ['id']),
                            child: Text(firstString(clinic, ['name'])),
                          ),
                      ],
                      onChanged: (value) => setState(() => _clinicId = value),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      helperText: 'South African mobile. Verify with SMS if you add one.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(onPressed: _busy ? null : _requestOtp, child: const Text('Send SMS code')),
                      if (_verificationToken != null) const Chip(label: Text('Phone verified')),
                    ],
                  ),
                  if (_otpHint != null) ...[const SizedBox(height: 8), Text(_otpHint!)],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _otp,
                    decoration: const InputDecoration(labelText: 'SMS code'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: _busy ? null : _verifyOtp, child: const Text('Verify code')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _aid,
                    decoration: const InputDecoration(labelText: 'Medical aid (optional)'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('None / not a member')),
                      for (final aid in _aids) DropdownMenuItem(value: aid, child: Text(aid)),
                    ],
                    onChanged: (value) => setState(() => _aid = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _idNumber,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'SA ID number (optional)'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consent,
                    onChanged: (value) => setState(() => _consent = value ?? false),
                    title: const Text('I accept the data-processing and privacy notice (POPIA).'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Creating account...' : 'Create account'),
                  ),
                  TextButton(onPressed: () => context.go('/login'), child: const Text('I already have an account')),
                ],
              ),
            ),
    );
  }
}
