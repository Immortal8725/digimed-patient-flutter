import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_client.dart';

class CareRepository {
  CareRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> profile() async =>
      asMap(await _api.get('/patients/me'));

  Future<List<Map<String, dynamic>>> clinics() async =>
      asList(await _api.get('/patients/me/clinics')).map(asMap).toList();

  Future<Map<String, dynamic>> selectClinic(String clinicId) async =>
      asMap(await _api.post('/patients/me/select-clinic/$clinicId'));

  Future<List<Map<String, dynamic>>> vitals() async {
    final data = asMap(await _api.get('/paperless/me/vitals'));
    if (data['linked'] == false) return const [];
    return asList(data['vitals'] ?? data).map(asMap).toList();
  }

  Future<List<Map<String, dynamic>>> todos() async {
    final data = await _api.get('/paperless/me/todos');
    return asList(asMap(data)['todos'] ?? data).map(asMap).toList();
  }

  Future<Map<String, dynamic>> mission() async =>
      asMap(await _api.get('/api/mission-control'));

  Future<List<Map<String, dynamic>>> medications() async => asList(
    await _api.get('/api/medications/me', query: {'activeOnly': true}),
  ).map(asMap).toList();

  Future<List<Map<String, dynamic>>> dosesToday() async =>
      asList(await _api.get('/api/medications/me/today')).map(asMap).toList();

  Future<String> logDose({
    required String medicationId,
    required String action,
    String? reminderId,
    String? scheduledAt,
  }) async {
    final data = asMap(
      await _api.post(
        '/api/medications/$medicationId/log',
        data: {
          if (reminderId != null && reminderId.isNotEmpty)
            'reminderId': reminderId,
          if (scheduledAt != null && scheduledAt.isNotEmpty)
            'scheduledAt': scheduledAt,
          'action': action,
        },
      ),
    );
    final adherence = str(data['adherencePercentage']);
    if (action == 'TAKEN' && adherence.isNotEmpty) {
      return 'Dose logged. Adherence $adherence%.';
    }
    if (action == 'TAKEN') return 'Dose logged.';
    if (action == 'SNOOZED') return 'Dose snoozed.';
    return 'Dose skipped.';
  }

  Future<Map<String, dynamic>> privacyNotice() async =>
      asMap(await _api.get('/api/privacy/notice'));

  Future<String> privacyShownAt() async {
    final data = await _api.get('/api/privacy/notice/shown');
    final rows = asList(data);
    if (rows.isEmpty) return firstString(asMap(data), ['shownAt']);
    return firstString(asMap(rows.first), ['shownAt']);
  }

  Future<String> confirmPrivacyShown() async {
    final data = asMap(await _api.post('/api/privacy/notice/shown', data: {}));
    return firstString(data, ['shownAt']);
  }

  Future<Map<String, dynamic>> privacyPolicy() async =>
      asMap(await _api.get('/api/consent/privacy'));

  Future<({List<Map<String, dynamic>> items, int unread})> appNotifications() async {
    final data = asMap(await _api.get('/api/notifications/mine'));
    return (
      items: asList(data['notifications'] ?? data).map(asMap).toList(),
      unread: asInt(data['unread']) ?? 0,
    );
  }

  Future<({List<Map<String, dynamic>> items, int unread})> paperlessNotifications() async {
    final data = asMap(await _api.get('/paperless/me/notifications'));
    return (
      items: asList(data['notifications'] ?? data).map(asMap).toList(),
      unread: asInt(data['unread']) ?? 0,
    );
  }

  Future<void> markNotificationsRead() async {
    await _api.post('/api/notifications/mine/read');
    try {
      await _api.post('/paperless/me/notifications/read');
    } catch (_) {}
  }

  Future<void> approvePermission(String id) async {
    await _api.post('/paperless/permissions/$id/approve');
  }

  Future<void> denyPermission(String id) async {
    await _api.post('/paperless/permissions/$id/deny');
  }

  Future<String> requestLinkOtp({
    required String identity,
    required String tenantId,
  }) async {
    final data = asMap(
      await _api.post(
        '/paperless/link/request-otp',
        data: {'identity': identity, 'tenantId': int.tryParse(tenantId) ?? tenantId},
      ),
    );
    final code = firstString(data, ['sessionOtp', 'simOtp']);
    final name = firstString(data, ['patientName']);
    final who = name.isEmpty ? 'your record' : name;
    if (code.isEmpty) return 'We found a record for $who. Enter the verification code.';
    return 'We found a record for $who. Your code is $code.';
  }

  Future<void> linkByIdentity({
    required String identity,
    required String otp,
    required String tenantId,
  }) async {
    await _api.post(
      '/paperless/link/by-identity',
      data: {
        'identity': identity,
        'otp': otp,
        'tenantId': int.tryParse(tenantId) ?? tenantId,
      },
    );
  }

  Future<Map<String, dynamic>> intakeForm({
    required String tenantId,
    String? appointmentId,
  }) async {
    return asMap(
      await _api.get(
        '/api/paperless/me/form',
        query: {
          'tenantId': tenantId,
          if (appointmentId != null && appointmentId.isNotEmpty)
            'appointmentId': appointmentId,
        },
      ),
    );
  }

  Future<void> submitIntake({
    required String tenantId,
    required String patientId,
    required String formId,
    required String userId,
    required String mode,
    String? appointmentId,
    required Map<String, dynamic> answers,
  }) async {
    await _api.post(
      '/api/paperless/submit',
      data: answers,
      query: {
        'tenantId': tenantId,
        'patientId': patientId,
        'formId': formId,
        'userId': userId,
        'ipAddress': '',
        'mode': mode,
        if (appointmentId != null && appointmentId.isNotEmpty)
          'appointmentId': appointmentId,
      },
    );
  }

  Future<Map<String, dynamic>> volunteer() async =>
      asMap(await _api.get('/api/research/volunteers/me'));

  Future<void> saveVolunteer(Map<String, dynamic> body) async {
    await _api.put('/api/research/volunteers/me', data: body);
  }

  Future<List<Map<String, dynamic>>> offers() async =>
      asList(await _api.get('/api/research/offers/inbox')).map(asMap).toList();

  Future<List<Map<String, dynamic>>> enrolments() async =>
      asList(await _api.get('/api/research/participants/my')).map(asMap).toList();

  Future<void> acceptOffer(String id) async {
    await _api.post('/api/research/offers/$id/accept');
  }

  Future<void> declineOffer(String id) async {
    await _api.post('/api/research/offers/$id/decline');
  }

  Future<void> signEconsent(String participantId) async {
    await _api.post('/api/research/participants/$participantId/consent');
  }

  Future<Map<String, dynamic>> consentCheck(String patientId) async => asMap(
    await _api.get(
      '/api/consent/check/$patientId',
      query: {'consentType': 'DATA_PROCESSING'},
    ),
  );

  Future<Map<String, dynamic>> saveConsent({
    required String patientId,
    required bool accepted,
  }) async {
    return asMap(
      await _api.post(
        '/api/consent',
        query: {'patientId': patientId},
        data: {
          'consentType': 'DATA_PROCESSING',
          'consentText':
              'I consent to the processing of my personal health data for medical purposes by authorized healthcare providers.',
          'accepted': accepted,
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> doctors(String tenantId) async =>
      asList(await _api.get('/api/doctors', query: {'tenantId': tenantId}))
          .map(asMap)
          .toList();

  Future<void> grantDoctor({
    required String patientId,
    required String userId,
    required String grantType,
    String? consentId,
  }) async {
    await _api.post(
      '/api/paperless/access/grant/$patientId',
      data: {
        'userId': int.tryParse(userId) ?? userId,
        'grantType': grantType,
        if (consentId != null && consentId.isNotEmpty) 'consentId': consentId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> rightsRequests() async {
    final data = await _api.get('/api/rights/me/requests');
    return asList(asMap(data)['requests'] ?? asMap(data)['items'] ?? data)
        .map(asMap)
        .toList();
  }

  Future<Map<String, dynamic>> exportData() async =>
      asMap(await _api.get('/api/rights/me/export'));

  Future<void> erasureRequest(String reason) async {
    await _api.post('/api/rights/me/erasure-request', data: {'reason': reason});
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    await _api.put('/api/rights/me/profile', data: body);
  }

  Future<Map<String, dynamic>> videoConsent(String appointmentId) async =>
      asMap(await _api.get('/api/telehealth/appointments/$appointmentId/consent'));

  Future<Map<String, dynamic>> recordVideoSuitability({
    required String appointmentId,
    required bool suitable,
  }) async {
    return asMap(
      await _api.post(
        '/api/telehealth/appointments/$appointmentId/consent',
        data: {'suitableForVideo': suitable},
      ),
    );
  }

  Future<Map<String, dynamic>> startVideoSession(String appointmentId) async =>
      asMap(await _api.post('/api/telehealth/appointments/$appointmentId/session'));

  Future<Map<String, dynamic>> room(String code) async =>
      asMap(await _api.get('/api/telehealth/rooms/${Uri.encodeComponent(code)}'));

  Future<Map<String, dynamic>> copayEstimate() async =>
      asMap(await _api.get('/api/copay/estimate/me'));

  Future<List<Map<String, dynamic>>> iceServers() async {
    final data = asMap(await _api.get('/public/telehealth/ice'));
    return asList(data['iceServers']).map(asMap).toList();
  }

  Future<Map<String, dynamic>> beginVideoRoom(String sessionId) async =>
      asMap(await _api.post('/api/telehealth/sessions/$sessionId/start'));

  Future<void> sendVideoSignal({
    required String sessionId,
    required String type,
    required Object? payload,
  }) async {
    await _api.post(
      '/api/telehealth/sessions/$sessionId/signal',
      data: {'type': type, 'payload': payload},
    );
  }

  Future<List<Map<String, dynamic>>> videoSignals({
    required String sessionId,
    required int afterId,
  }) async {
    final data = await _api.get(
      '/api/telehealth/sessions/$sessionId/signals',
      query: {'afterId': afterId},
    );
    return asList(data).map(asMap).toList();
  }

  Future<Map<String, dynamic>> endVideoRoom(String sessionId) async =>
      asMap(await _api.post('/api/telehealth/sessions/$sessionId/end'));
}

final careRepositoryProvider = Provider<CareRepository>(
  (ref) => CareRepository(ref.watch(apiClientProvider)),
);
