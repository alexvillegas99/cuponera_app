// lib/services/otp_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OtpService {
  final String base = dotenv.env['API_URL'] ?? '';

  Uri _uri(String path) => Uri.parse('$base$path');

  /// 🔹 Genera y envía el OTP
Future<Map<String, dynamic>> sendOtp(String email) async {
  final uri = _uri('/otps/generate');
  final resp = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email}),
  );

  // 🔹 Para debug opcional
  print('[OTP] status=${resp.statusCode} body=${resp.body}');

  if (resp.statusCode == 200 || resp.statusCode == 201) {
    if (resp.body.isNotEmpty) {
      try {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        // no era JSON → devolver vacío
        return {};
      }
    }
    return {};
  } else {
    throw Exception(_extractMessage(resp.body));
  }
}


  /// 🔹 Verifica el OTP
  Future<bool> verifyOtp(String email, String code) async {
    final uri = _uri('/otps/verify');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    if (resp.statusCode == 200 || resp.statusCode ==201) return true;

    throw Exception(_extractMessage(resp.body));
  }

  /// 🔹 Extrae solo el mensaje legible
  String _extractMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        if (data['message'] is Map) {
          return data['message']['message']?.toString() ?? 'Error desconocido';
        }
        if (data['message'] is String) {
          return data['message'];
        }
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}
