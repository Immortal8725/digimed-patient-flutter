import 'package:digimed_connect/features/auth/auth_gate.dart';
import 'package:digimed_connect/features/auth/auth_models.dart';
import 'package:digimed_connect/features/auth/auth_repository.dart';
import 'package:digimed_connect/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaffAuthRepository implements AuthRepository {
  @override
  Future<PatientSession> login({
    required String username,
    required String password,
  }) async {
    throw const StaffAccessRejected();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<OtpChallenge> requestOtp({
    required String phone,
    String? email,
    String? clinicId,
    required String purpose,
  }) async => const OtpChallenge();

  @override
  Future<PatientSession?> restore() async => null;

  @override
  Future<void> signup(Map<String, dynamic> body) async {}

  @override
  Future<String> verifyOtp({
    required String phone,
    required String code,
    required String purpose,
  }) async => '';
}

void main() {
  test('staff roles are blocked and patients are allowed', () {
    expect(staffLoginBlock('PATIENT'), isNull);
    expect(staffLoginBlock('patient'), isNull);
    expect(staffLoginBlock('DOCTOR'), staffWebAppMessage);
    expect(staffLoginBlock('NURSE'), staffWebAppMessage);
    expect(staffLoginBlock('RECEPTIONIST'), staffWebAppMessage);
    expect(staffLoginBlock('TENANT_ADMIN'), staffWebAppMessage);
    expect(staffLoginBlock(null), staffWebAppMessage);
  });

  testWidgets('staff sign in shows the web app message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StaffAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('login-username')), 'sister.nkosi');
    await tester.enterText(find.byKey(const Key('login-password')), 'secret');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    await tester.pump();

    expect(find.text(staffWebAppMessage), findsOneWidget);
    expect(find.textContaining('web app'), findsWidgets);
  });
}
