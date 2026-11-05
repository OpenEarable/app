import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../configs/overall_config.dart';
import 'user_account.dart';

const int tencentPremiumMaleVoiceType =
    OverallMeditationConfig.tencentPremiumMaleVoiceType;
const int tencentPremiumFemaleVoiceType =
    OverallMeditationConfig.tencentPremiumFemaleVoiceType;

class TencentTtsException implements Exception {
  final String message;

  const TencentTtsException(this.message);

  @override
  String toString() => 'TencentTtsException: $message';
}

class TencentTc3Signer {
  static const String algorithm = 'TC3-HMAC-SHA256';
  static const String service = 'tts';
  static const String contentType = 'application/json; charset=utf-8';

  const TencentTc3Signer._();

  static Map<String, String> headers({
    required String secretId,
    required String secretKey,
    required String host,
    required String region,
    required String payload,
    required DateTime timestamp,
  }) {
    final utcTimestamp = timestamp.toUtc();
    final unixTimestamp = utcTimestamp.millisecondsSinceEpoch ~/ 1000;
    final date = _date(utcTimestamp);
    const signedHeaders = 'content-type;host';
    final canonicalHeaders = 'content-type:$contentType\nhost:$host\n';
    final hashedPayload = sha256.convert(utf8.encode(payload)).toString();
    final canonicalRequest = [
      'POST',
      '/',
      '',
      canonicalHeaders,
      signedHeaders,
      hashedPayload,
    ].join('\n');

    final credentialScope = '$date/$service/tc3_request';
    final hashedCanonicalRequest =
        sha256.convert(utf8.encode(canonicalRequest)).toString();
    final stringToSign = [
      algorithm,
      unixTimestamp.toString(),
      credentialScope,
      hashedCanonicalRequest,
    ].join('\n');

    final secretDate = _hmac(utf8.encode('TC3$secretKey'), date);
    final secretService = _hmac(secretDate, service);
    final secretSigning = _hmac(secretService, 'tc3_request');
    final signature = _hex(_hmac(secretSigning, stringToSign));
    final authorization = '$algorithm Credential=$secretId/$credentialScope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    return {
      'Authorization': authorization,
      'Content-Type': contentType,
      'Host': host,
      'X-TC-Action': 'TextToVoice',
      'X-TC-Version': '2019-08-23',
      'X-TC-Timestamp': unixTimestamp.toString(),
      'X-TC-Region': region,
    };
  }

  static List<int> _hmac(List<int> key, String message) {
    return Hmac(sha256, key).convert(utf8.encode(message)).bytes;
  }

  static String _hex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _date(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  }
}

class TencentTtsClient {
  final http.Client _httpClient;
  final bool _ownsClient;
  final Duration timeout;

  TencentTtsClient({
    http.Client? httpClient,
    this.timeout = OverallMeditationConfig.tencentRequestTimeout,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  Future<Uint8List> synthesize({
    required String text,
    required String secretId,
    required String secretKey,
    required TencentTtsRegion region,
    required int voiceType,
    required double speed,
    DateTime? requestTime,
  }) async {
    if (secretId.trim().isEmpty || secretKey.trim().isEmpty) {
      throw const TencentTtsException(
        'Tencent SecretId and SecretKey are both required.',
      );
    }
    if (text.trim().isEmpty) {
      throw const TencentTtsException('Text cannot be empty.');
    }

    final sessionId =
        'earstream-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final payload = jsonEncode({
      'Text': text,
      'SessionId': sessionId,
      'Volume': OverallMeditationConfig.tencentVolume,
      'Speed': speed,
      'ProjectId': OverallMeditationConfig.tencentProjectId,
      'ModelType': OverallMeditationConfig.tencentModelType,
      'VoiceType': voiceType,
      'PrimaryLanguage': OverallMeditationConfig.tencentPrimaryLanguageEnglish,
      'SampleRate': OverallMeditationConfig.tencentSampleRate,
      'Codec': OverallMeditationConfig.tencentCodec,
      'EnableSubtitle': OverallMeditationConfig.tencentEnableSubtitle,
    });
    final endpoint = Uri.https(region.host, '/');
    final headers = TencentTc3Signer.headers(
      secretId: secretId,
      secretKey: secretKey,
      host: region.host,
      region: region.region,
      payload: payload,
      timestamp: requestTime ?? DateTime.now().toUtc(),
    );

    final http.Response response;
    try {
      response = await _httpClient
          .post(endpoint, headers: headers, body: payload)
          .timeout(timeout);
    } catch (error) {
      throw TencentTtsException('Network request failed: $error');
    }

    Map<String, dynamic> decoded;
    try {
      decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw TencentTtsException(
        'Tencent returned an unreadable response (${response.statusCode}).',
      );
    }

    final responseBody = decoded['Response'];
    if (responseBody is! Map<String, dynamic>) {
      throw TencentTtsException(
        'Tencent returned an invalid response (${response.statusCode}).',
      );
    }

    final error = responseBody['Error'];
    if (response.statusCode != 200 || error is Map) {
      final code = error is Map ? error['Code']?.toString() : null;
      final message = error is Map ? error['Message']?.toString() : null;
      throw TencentTtsException(
        [
          if (code != null) code,
          if (message != null) message,
          if (code == null && message == null) 'HTTP ${response.statusCode}',
        ].join(': '),
      );
    }

    final encodedAudio = responseBody['Audio'];
    if (encodedAudio is! String || encodedAudio.isEmpty) {
      throw const TencentTtsException('Tencent returned no audio data.');
    }

    try {
      return base64Decode(encodedAudio);
    } catch (_) {
      throw const TencentTtsException('Tencent returned invalid audio data.');
    }
  }

  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }
}

/// Tencent TextToVoice accepts at most 500 Latin letters or 150 Chinese
/// characters. This conservative weighted splitter stays below both limits.
List<String> splitTencentTtsText(
  String text, {
  int maxUnits = OverallMeditationConfig.tencentTextChunkMaxUnits,
}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return const [];

  int units(String value) {
    var total = 0;
    for (final rune in value.runes) {
      total += _isCjk(rune) ? 4 : 1;
    }
    return total;
  }

  final chunks = <String>[];
  var current = '';
  final pieces = normalized.split(
    RegExp(r'(?<=[.!?;:\u3002\uff01\uff1f\uff1b])\s+'),
  );

  void addPiece(String piece) {
    final candidate = current.isEmpty ? piece : '$current $piece';
    if (units(candidate) <= maxUnits) {
      current = candidate;
      return;
    }
    if (current.isNotEmpty) {
      chunks.add(current);
      current = '';
    }

    final words = piece.split(' ');
    for (final word in words) {
      final next = current.isEmpty ? word : '$current $word';
      if (units(next) <= maxUnits) {
        current = next;
        continue;
      }
      if (current.isNotEmpty) {
        chunks.add(current);
        current = '';
      }

      var runeBuffer = <int>[];
      var runeUnits = 0;
      for (final rune in word.runes) {
        final weight = _isCjk(rune) ? 4 : 1;
        if (runeBuffer.isNotEmpty && runeUnits + weight > maxUnits) {
          chunks.add(String.fromCharCodes(runeBuffer));
          runeBuffer = <int>[];
          runeUnits = 0;
        }
        runeBuffer.add(rune);
        runeUnits += weight;
      }
      current = String.fromCharCodes(runeBuffer);
    }
  }

  for (final piece in pieces) {
    addPiece(piece);
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

bool _isCjk(int rune) {
  return (rune >= 0x3400 && rune <= 0x9fff) ||
      (rune >= 0xf900 && rune <= 0xfaff);
}
