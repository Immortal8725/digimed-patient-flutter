import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import '../auth/auth_repository.dart';
import '../medical_aid/medical_aid_card.dart';
import 'care_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _info;
  Map<String, dynamic> _profile = {};
  String? _verificationToken;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(careRepositoryProvider).profile();
      if (!mounted) return;
      _email.text = firstString(profile, ['email']);
      _phone.text = firstString(profile, ['phone']);
      setState(() {
        _profile = profile;
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

  Future<void> _saveEmail() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(careRepositoryProvider).updateProfile({'email': email});
      if (mounted) setState(() => _info = 'Email updated.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendOtp() async {
    try {
      final challenge = await ref.read(authRepositoryProvider).requestOtp(
        phone: _phone.text.trim(),
        purpose: 'profile-phone',
      );
      if (!mounted) return;
      final preview = challenge.previewCode.isEmpty ? '' : ' Code: ${challenge.previewCode}.';
      setState(() => _info = 'Code sent.${challenge.maskedPhone.isEmpty ? '' : ' ${challenge.maskedPhone}.'}$preview');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _verify() async {
    try {
      final token = await ref.read(authRepositoryProvider).verifyOtp(
        phone: _phone.text.trim(),
        code: _otp.text,
        purpose: 'profile-phone',
      );
      if (mounted) {
        setState(() {
          _verificationToken = token;
          _info = 'Phone verified. Save it to your profile.';
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _savePhone() async {
    final phone = _phone.text.trim();
    final sameVerified =
        phone.isNotEmpty &&
        phone == firstString(_profile, ['phone']) &&
        asBool(_profile['phoneVerified']);
    if (phone.isNotEmpty && !sameVerified && _verificationToken == null) {
      setState(() => _error = 'Verify the new number with the SMS code first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(careRepositoryProvider).updateProfile({
        'phone': phone,
        if (_verificationToken != null) 'phoneVerificationToken': _verificationToken,
      });
      if (mounted) setState(() => _info = phone.isEmpty ? 'Phone removed.' : 'Phone saved and verified.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = asBool(_profile['phoneVerified']);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const LoadingView(label: 'Loading profile')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(firstString(_profile, ['fullName', 'username'])),
                const SizedBox(height: 8),
                const Text('Phone numbers must be verified with an SMS code.'),
                if (_info != null) Text(_info!),
                if (_error != null) Text(_error!),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _saveEmail,
                  child: const Text('Save email'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phone,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    helperText: verified ? 'Verified on file' : 'Not verified',
                  ),
                ),
                TextField(
                  controller: _otp,
                  decoration: const InputDecoration(labelText: 'SMS code'),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(onPressed: _sendOtp, child: const Text('Send code')),
                    OutlinedButton(onPressed: _verify, child: const Text('Verify')),
                    FilledButton(
                      onPressed: _busy ? null : _savePhone,
                      child: const Text('Save phone'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const MedicalAidSection(),
              ],
            ),
    );
  }
}
