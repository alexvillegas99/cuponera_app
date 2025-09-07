import 'dart:convert';

String extractErrorMessage(int status, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final m = decoded['message'];
      if (m is String && m.trim().isNotEmpty) return m;
      if (m is Map<String, dynamic>) {
        final inner = m['message'];
        if (inner is String && inner.trim().isNotEmpty) return inner;
        if (m['error'] is String && (m['error'] as String).trim().isNotEmpty) {
          return '${m['error']} (HTTP $status)';
        }
      }
      if (decoded['error'] is String) {
        return '${decoded['error']} (HTTP $status)';
      }
    }
  } catch (_) {}
  return 'Error $status';
}
