import '../../core/json/json_values.dart';

class PatientSession {
  const PatientSession({
    required this.token,
    required this.role,
    this.userId = '',
    this.tenantId = '',
    this.tenantType = 'CLINIC',
  });

  final String token;
  final String role;
  final String userId;
  final String tenantId;
  final String tenantType;

  factory PatientSession.fromLogin(Map<String, dynamic> body) {
    return PatientSession(
      token: firstString(body, ['token', 'accessToken']),
      role: firstString(body, ['role']),
      userId: firstString(body, ['userId', 'id']),
      tenantId: firstString(body, ['tenantId']),
      tenantType: firstString(body, ['tenantType']).isEmpty
          ? 'CLINIC'
          : firstString(body, ['tenantType']),
    );
  }
}

class OtpChallenge {
  const OtpChallenge({
    this.maskedPhone = '',
    this.maskedEmail = '',
    this.previewCode = '',
  });

  final String maskedPhone;
  final String maskedEmail;
  final String previewCode;
}
