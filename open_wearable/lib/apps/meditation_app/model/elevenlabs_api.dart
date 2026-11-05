import 'dart:convert';

import 'package:http/http.dart' as http;

class ElevenLabsApiException implements Exception {
  final int statusCode;
  final String? providerCode;
  final String message;

  const ElevenLabsApiException({
    required this.statusCode,
    required this.message,
    this.providerCode,
  });

  factory ElevenLabsApiException.fromResponse(http.Response response) {
    String? providerCode;
    String? providerMessage;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is Map<String, dynamic>) {
          providerCode = detail['status']?.toString();
          providerMessage = detail['message']?.toString();
        } else if (detail is String) {
          providerMessage = detail;
        }
      }
    } catch (_) {
      // Keep the fallback below concise and avoid exposing an arbitrary body.
    }

    return ElevenLabsApiException(
      statusCode: response.statusCode,
      providerCode: providerCode,
      message: providerMessage?.trim().isNotEmpty == true
          ? providerMessage!.trim()
          : 'ElevenLabs rejected the request.',
    );
  }

  @override
  String toString() {
    final code = providerCode == null ? '' : ' ($providerCode)';
    return 'ElevenLabs HTTP $statusCode$code: $message';
  }
}
