/// Backend addresses for the DigiMed Connect patient app.
///
/// Override at build or run time:
/// `--dart-define=API_BASE_URL=https://...`
/// `--dart-define=REALTIME_URL=https://...`
class ApiConfig {
  const ApiConfig._();

  static const String defaultApiBaseUrl =
      'https://healthcare-backend-production-9a4a.up.railway.app';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );

  /// Empty unless `--dart-define=REALTIME_URL=...` is set.
  static const String realtimeUrl = String.fromEnvironment('REALTIME_URL');

  static String get normalizedBase {
    final trimmed = apiBaseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static bool get realtimeEnabled => realtimeUrl.trim().isNotEmpty;
}
