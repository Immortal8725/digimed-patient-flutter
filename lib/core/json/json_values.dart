Map<String, dynamic> asMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<dynamic> asList(Object? value) {
  if (value is List) return value;
  final map = asMap(value);
  for (final key in const [
    'items',
    'data',
    'results',
    'content',
    'notifications',
    'todos',
    'vitals',
    'requests',
    'practices',
    'providers',
    'questions',
    'records',
  ]) {
    final nested = map[key];
    if (nested is List) return nested;
  }
  return const [];
}

String str(Object? value) {
  if (value == null) return '';
  return value.toString().trim();
}

String firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = str(map[key]);
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(str(value));
}

bool asBool(Object? value) {
  if (value is bool) return value;
  final text = str(value).toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

String apiMessage(Object? data, String fallback) {
  final map = asMap(data);
  final message = firstString(map, ['error', 'message', 'detail']);
  return message.isEmpty ? fallback : message;
}
