import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_store.dart';
import 'auth_gate.dart';
import 'auth_models.dart';

abstract class AuthRepository {
  Future<PatientSession?> restore();
  Future<PatientSession> login({
    required String username,
    required String password,
  });
  Future<void> logout();
  Future<void> signup(Map<String, dynamic> body);
  Future<OtpChallenge> requestOtp({
    required String phone,
    String? email,
    String? clinicId,
    required String purpose,
  });
  Future<String> verifyOtp({
    required String phone,
    required String code,
    required String purpose,
  });
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._store);

  final ApiClient _api;
  final TokenStore _store;

  @override
  Future<PatientSession> login({
    required String username,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/login',
      data: {'username': username.trim(), 'password': password},
    );
    final body = asMap(data);
    final role = firstString(body, ['role']);
    if (staffLoginBlock(role) != null) {
      throw const StaffAccessRejected();
    }
    final session = PatientSession.fromLogin(body);
    if (session.token.isEmpty) {
      throw const ApiException('Login response did not include a token.');
    }
    await _persist(session);
    return session;
  }

  @override
  Future<void> logout() => _store.clear();

  @override
  Future<OtpChallenge> requestOtp({
    required String phone,
    String? email,
    String? clinicId,
    required String purpose,
  }) async {
    final data = await _api.post(
      '/auth/phone/request-otp',
      data: {
        'phone': phone,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (clinicId != null && clinicId.isNotEmpty) 'clinicId': clinicId,
        'purpose': purpose,
      },
    );
    final body = asMap(data);
    return OtpChallenge(
      maskedPhone: firstString(body, ['maskedPhone']),
      maskedEmail: firstString(body, ['maskedEmail']),
      previewCode: firstString(body, ['sessionOtp', 'simOtp', 'code']),
    );
  }

  @override
  Future<PatientSession?> restore() async {
    final token = await _store.read('token');
    final role = await _store.read('role');
    if (token == null || token.isEmpty || staffLoginBlock(role) != null) {
      if (token != null && token.isNotEmpty) await _store.clear();
      return null;
    }
    return PatientSession(
      token: token,
      role: role ?? 'PATIENT',
      userId: await _store.read('userId') ?? '',
      tenantId: await _store.read('tenantId') ?? '',
      tenantType: await _store.read('tenantType') ?? 'CLINIC',
    );
  }

  @override
  Future<void> signup(Map<String, dynamic> body) async {
    await _api.post('/auth/patient-signup', data: body);
  }

  @override
  Future<String> verifyOtp({
    required String phone,
    required String code,
    required String purpose,
  }) async {
    final data = await _api.post(
      '/auth/phone/verify-otp',
      data: {'phone': phone, 'code': code.trim(), 'purpose': purpose},
    );
    final token = firstString(asMap(data), ['phoneVerificationToken']);
    if (token.isEmpty) {
      throw const ApiException('The verification code was not accepted.');
    }
    return token;
  }

  Future<void> _persist(PatientSession session) async {
    await _store.write('token', session.token);
    await _store.write('role', session.role);
    if (session.userId.isNotEmpty) {
      await _store.write('userId', session.userId);
    }
    if (session.tenantId.isNotEmpty) {
      await _store.write('tenantId', session.tenantId);
    }
    await _store.write('tenantType', session.tenantType);
  }

  Future<void> saveRefreshedSession(PatientSession session) => _persist(session);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});
