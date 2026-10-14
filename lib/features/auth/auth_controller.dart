import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/realtime/realtime_service.dart';
import '../../core/storage/token_store.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

class AuthController extends AsyncNotifier<PatientSession?> {
  @override
  Future<PatientSession?> build() async {
    final session = await ref.read(authRepositoryProvider).restore();
    if (session != null) {
      ref.read(realtimeServiceProvider).connect(session.token);
    }
    return session;
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final session = await ref.read(authRepositoryProvider).login(
      username: username,
      password: password,
    );
    ref.read(realtimeServiceProvider).connect(session.token);
    state = AsyncData(session);
  }

  Future<void> logout() async {
    ref.read(realtimeServiceProvider).disconnect();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  Future<void> sessionExpired() async {
    ref.read(realtimeServiceProvider).disconnect();
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }

  Future<void> rememberToken(String token, {String? tenantId}) async {
    final current = state.value;
    if (current == null) return;
    await ref.read(tokenStoreProvider).write('token', token);
    if (tenantId != null && tenantId.isNotEmpty) {
      await ref.read(tokenStoreProvider).write('tenantId', tenantId);
    }
    final next = PatientSession(
      token: token,
      role: current.role,
      userId: current.userId,
      tenantId: tenantId ?? current.tenantId,
      tenantType: current.tenantType,
    );
    ref.read(realtimeServiceProvider).connect(token);
    state = AsyncData(next);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, PatientSession?>(AuthController.new);
