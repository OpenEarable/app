import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../configs/overall_config.dart';
import 'demo_fallback_script.dart';
import 'user_account.dart';
import 'hr_hrv_processor.dart' show HeartRateSample;
import 'meditation_prompt_policy.dart';

class MeditationSegment {
  final int segmentId;
  final String instruction;
  final int durationSeconds;

  const MeditationSegment({
    required this.segmentId,
    required this.instruction,
    required this.durationSeconds,
  });

  factory MeditationSegment.fromJson(
    Map<String, dynamic> json, {
    required Duration minimumDuration,
  }) {
    return MeditationSegment(
      segmentId: json['segmentId'] as int,
      instruction: json['instruction'] as String,
      // Segment timing is app-controlled. This prevents an LLM response from
      // accidentally reintroducing the demo's 30-second timing into a regular
      // narration-driven session.
      durationSeconds: minimumDuration.inSeconds,
    );
  }
}

class MeditationFrame {
  final String welcomeMessage;
  final String completionMessage;
  final MeditationSegment firstSegment;

  const MeditationFrame({
    required this.welcomeMessage,
    required this.completionMessage,
    required this.firstSegment,
  });
}

abstract interface class MeditationScript {
  // Begins the meditation, returning the opening frame (welcome message, completion message, and first segment).
  Future<MeditationFrame> begin();

  /// The next segment, adapted to [current], or null when the script is done.
  /// [current] may be null for meditations with no biosignal source.
  Future<MeditationSegment?> nextSegment(HeartRateSample? current);

  void dispose();
}

/// Chooses the right script for the account: adaptive if an LLM key is present,
/// static otherwise.
MeditationScript createMeditationScript({
  required UserAccount account,
  required int maxSegments,
  Duration? segmentDuration,
  MeditationPromptPolicy promptPolicy = MeditationPromptPolicy.standard,
}) {
  if (account.allowsCloudProcessing && account.hasValidDeepseekKey) {
    return AdaptiveMeditationScript(
      account: account,
      maxSegments: maxSegments,
      segmentDuration: segmentDuration,
      promptPolicy: promptPolicy,
    );
  }
  return createFallbackScript(
    account: account,
    maxSegments: maxSegments,
    segmentDuration: segmentDuration,
    promptPolicy: promptPolicy,
  );
}

/// The script used when generation is unavailable, either because there is no
/// key or because a request failed.
///
/// The conference demo gets narration written for the attendee's chosen
/// meditation type and environment; every other mode gets the single generic
/// script, which a user can simply restart into a working session.
MeditationScript createFallbackScript({
  required UserAccount account,
  required int maxSegments,
  Duration? segmentDuration,
  MeditationPromptPolicy promptPolicy = MeditationPromptPolicy.standard,
}) {
  if (promptPolicy != MeditationPromptPolicy.conferenceDemo) {
    return StaticMeditationScript.fallback(
      segmentCount: maxSegments,
      segmentDuration: segmentDuration,
    );
  }

  return StaticMeditationScript(
    welcome: DemoFallbackScript.welcomeFor(account),
    completion: DemoFallbackScript.completionFor(account),
    segments: List.generate(
      maxSegments,
      (i) => DemoFallbackScript.segmentFor(
        account: account,
        index: i + 1,
        duration: segmentDuration,
      ),
    ),
  );
}

class StaticMeditationScript implements MeditationScript {
  final String _welcome;
  final String _completion;
  final List<MeditationSegment> _segments;
  int _index = 0;

  StaticMeditationScript({
    required String welcome,
    required String completion,
    required List<MeditationSegment> segments,
  })  : _welcome = welcome,
        _completion = completion,
        _segments = segments;

  factory StaticMeditationScript.fallback({
    required int segmentCount,
    Duration? segmentDuration,
  }) {
    return StaticMeditationScript(
      welcome: _Fallback.welcome,
      completion: _Fallback.completion,
      segments: List.generate(
        segmentCount,
        (i) => _Fallback.segment(i + 1, segmentDuration),
      ),
    );
  }

  @override
  Future<MeditationFrame> begin() async {
    _index = 1;
    return MeditationFrame(
      welcomeMessage: _welcome,
      completionMessage: _completion,
      firstSegment: _segments.first,
    );
  }

  @override
  Future<MeditationSegment?> nextSegment(HeartRateSample? _) async {
    if (_index >= _segments.length) return null;
    return _segments[_index++];
  }

  @override
  void dispose() {}
}

class AdaptiveMeditationScript implements MeditationScript {
  final UserAccount _account;
  final int _maxSegments;
  final Duration? _segmentDuration;
  final http.Client _client;
  final bool _ownsClient;
  final MeditationPromptPolicy _promptPolicy;

  final List<Map<String, String>> _history = [];
  int _emitted = 0;

  AdaptiveMeditationScript({
    required UserAccount account,
    required int maxSegments,
    Duration? segmentDuration,
    MeditationPromptPolicy promptPolicy = MeditationPromptPolicy.standard,
    http.Client? client,
  })  : _account = account,
        _maxSegments = maxSegments,
        _segmentDuration = segmentDuration,
        _promptPolicy = promptPolicy,
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  static final _endpoint = Uri.parse(
    '${OverallMeditationConfig.deepseekApiBaseUrl}'
    '${OverallMeditationConfig.deepseekChatPath}',
  );

  Duration get _minimumDuration =>
      _segmentDuration ??
      OverallMeditationConfig.standardNarrationMinimumDuration;

  int get _durationSeconds => _minimumDuration.inSeconds;

  @override
  Future<MeditationFrame> begin() async {
    _history.add({'role': 'user', 'content': _openingPrompt()});
    final content = await _send(); // throws on failure — caller falls back
    _history.add({'role': 'assistant', 'content': content});

    final json = jsonDecode(content) as Map<String, dynamic>;
    _emitted = 1;
    return MeditationFrame(
      welcomeMessage: json['welcomeMessage'] as String,
      completionMessage: json['completionMessage'] as String,
      firstSegment: MeditationSegment.fromJson(
        json['segment'] as Map<String, dynamic>,
        minimumDuration: _minimumDuration,
      ),
    );
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<MeditationSegment?> nextSegment(HeartRateSample? current) async {
    if (_emitted >= _maxSegments) return null;

    _history.add({'role': 'user', 'content': _segmentPrompt(current)});
    try {
      final content = await _send();
      _history.add({'role': 'assistant', 'content': content});
      final json = jsonDecode(content) as Map<String, dynamic>;
      _emitted++;
      return MeditationSegment.fromJson(
        json,
        minimumDuration: _minimumDuration,
      );
    } catch (e) {
      // Resilience: a single failed call must not end the meditation. Drop the
      // dangling user turn, emit a generic segment, and let the session go on.
      debugPrint('Adaptive segment failed, using fallback: $e');
      _history.removeLast();
      _emitted++;
      if (_promptPolicy == MeditationPromptPolicy.conferenceDemo) {
        return DemoFallbackScript.segmentFor(
          account: _account,
          index: _emitted,
          duration: _minimumDuration,
        );
      }
      return _Fallback.segment(_emitted, _segmentDuration);
    }
  }

  /// Posts the system prompt + full history, returns the assistant's raw
  /// content string. Throws when the request or response is invalid.
  Future<String> _send() async {
    final key = _account.deepseekApiKey;
    if (key == null) {
      throw Exception('No DeepSeek API key.');
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': OverallMeditationConfig.deepseekModel,
              'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'system', 'content': _systemPrompt()},
                ..._history,
              ],
              'max_tokens': OverallMeditationConfig.deepseekMaxTokens,
              'temperature': OverallMeditationConfig.deepseekTemperature,
            }),
          )
          .timeout(OverallMeditationConfig.deepseekRequestTimeout);
    } catch (e) {
      throw Exception('Network error. $e');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'DeepSeek returned HTTP ${response.statusCode}.',
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded['choices'][0]['message']['content'] as String;
    } catch (e) {
      throw Exception('Malformed response. $e');
    }
  }

  // --- prompt building -----------------------------------------------------

  String _systemPrompt() {
    if (!_promptPolicy.includeProfileInformation) {
      return _conferenceDemoSystemPrompt();
    }

    final meditationType =
        _account.meditationType?.label ?? MeditationType.mindfulness.label;
    final userContext = _account.getContextSummary();

    return '''
You are a highly empathetic, warm, and professional meditation guide with a naturally calming voice.
You lead a personalized, ADAPTIVE meditation that unfolds one segment at a time. After each segment I will report the user's live biosignals, and you will adapt the next segment to guide them toward calm.

LANGUAGE — STRICT:
Write every string you output in English only. The welcomeMessage, the completionMessage, and every instruction must be entirely in English.
Never use Chinese, Japanese, Korean, or any other language, and never include CJK or other non-Latin characters, not even a single word, name, or decorative character.
This applies to every turn of the conversation, not only the first.

$userContext

MEDITATION TYPE: $meditationType
Stay true to this meditation type throughout.

HOW TO ADAPT TO BIOSIGNALS (reported after each segment):
- Heart rate (bpm): lower is calmer. A rising or high HR means the user is still activated — slow down, lengthen exhales, soften the language.
- HRV as RMSSD (ms): HIGHER RMSSD means more relaxed (parasympathetic). LOW RMSSD means stressed — keep grounding and steady the breath before deepening.
- If the user is clearly calming, you may gently deepen the practice. If not, stay with soothing, stabilizing guidance. Never rush them.

GUIDELINES:
1. ALWAYS include clear breathing guidance in every segment, and NEVER count it out. Do not use counts, numerals, or number words to time the breath: no "in for 4, out for 6", no "hold for a count of three". Shape the breath with words and pauses instead, for example "breathe in slowly... and let the out-breath run longer than the in-breath... let the last of it go".
2. Make it PERSONAL: use their name occasionally, reference their environment imagery, adapt to their profile.
3. Create natural transitions that build on what you said before. DO NOT signal an ending in a segment.
4. Speak slowly; use soothing language and natural pauses marked with ellipses (...).
5. Approximately ${OverallMeditationConfig.standardPromptApproximateWordsPerSegment} words per segment.
6. Write in English. Every word spoken to the user is English.

OUTPUT FORMAT — valid JSON only, no markdown, no commentary. All string values must be written in English.

On the FIRST turn, output:
{
  "welcomeMessage": "string",
  "completionMessage": "string",
  "segment": {
    "segmentId": 1,
    "instruction": "string"
  }
}

On EVERY LATER turn, output a single segment object:
{
  "segmentId": <int>,
  "instruction": "string"
}

Remember: you're creating a calming, safe space for someone who may be stressed. Be warm, patient, and genuinely caring.''';
  }

  String _conferenceDemoSystemPrompt() {
    final meditationType =
        _account.meditationType?.label ?? MeditationType.mindfulness.label;
    final environment = _account.meditationEnvironment?.label ??
        MeditationEnvironment.forest.label;

    return '''
You are a highly empathetic, warm, and professional meditation guide with a naturally calming voice.
You lead a meditation that unfolds one segment at a time for a short conference demonstration.

LANGUAGE - STRICT:
Write every string you output in English only. The welcomeMessage, the completionMessage, and every instruction must be entirely in English.
Never use Chinese, Japanese, Korean, or any other language, and never include CJK or other non-Latin characters, not even a single word, name, or decorative character.
This applies to every turn of the conversation, not only the first.

SESSION-ONLY PREFERENCES:
- Meditation type: $meditationType
- Imagery environment: $environment

PRIVACY REQUIREMENTS:
- Do not request, infer, mention, or invent a name, age, gender, fitness level, health status, permanent profile, or physiological measurement.
- Use only the two session preferences above to shape the meditation.

GUIDELINES:
1. ALWAYS include clear breathing guidance in every segment, and NEVER count it out. Do not use counts, numerals, or number words to time the breath: no "in for 4, out for 6", no "hold for a count of three". Shape the breath with words and pauses instead, for example "breathe in slowly... and let the out-breath run longer than the in-breath... let the last of it go".
2. Use the selected imagery environment naturally, without claiming personal knowledge about the participant.
3. Create natural transitions that build on what you said before. DO NOT signal an ending in a segment.
4. Speak slowly; use soothing language and natural pauses marked with ellipses (...).
5. Fit the spoken guidance naturally into approximately $_durationSeconds seconds.
6. Write in English. Every word spoken to the participant is English.

OUTPUT FORMAT - valid JSON only, no markdown, no commentary. All string values must be written in English.

On the FIRST turn, output:
{
  "welcomeMessage": "string",
  "completionMessage": "string",
  "segment": {
    "segmentId": 1,
    "instruction": "string",
    "durationSeconds": $_durationSeconds
  }
}

On EVERY LATER turn, output a single segment object:
{
  "segmentId": <int>,
  "instruction": "string",
  "durationSeconds": $_durationSeconds
}

Create a calming and safe experience while respecting the privacy requirements.''';
  }

  String _openingPrompt() {
    if (!_promptPolicy.includePhysiologicalInformation) {
      return 'Begin the session. Generate the welcomeMessage, the '
          'completionMessage, and the first segment in the first-turn JSON '
          'format using only the session preferences.';
    }
    return 'Begin the session. Generate the welcomeMessage, the '
        'completionMessage, and the first segment, in the first-turn JSON '
        'format. There are no biosignals yet.';
  }

  String _segmentPrompt(HeartRateSample? b) {
    final next = _emitted + 1;
    if (!_promptPolicy.includePhysiologicalInformation) {
      return 'The participant has finished segment $_emitted. Generate '
          'segment $next as a single segment JSON object, continuing the '
          'calming progression using only the session preferences. '
          '$_noCountingReminder$_englishOnlyReminder';
    }
    if (b == null) {
      return 'The user has finished segment $_emitted. No biosignals are '
          'available. Generate segment $next as a single segment JSON object, '
          'continuing the calming progression. '
          '$_noCountingReminder$_englishOnlyReminder';
    }
    final hr = b.heartRate.toStringAsFixed(0);
    final rmssdDescription = b.rmssd == null
        ? 'HRV (RMSSD) is currently unavailable'
        : 'HRV (RMSSD) is ${b.rmssd!.toStringAsFixed(0)} ms';
    return 'The user has finished segment $_emitted. Their current heart rate '
        'is $hr bpm and their $rmssdDescription. Adapt accordingly and '
        'generate segment $next as a single segment JSON object. '
        '$_noCountingReminder$_englishOnlyReminder';
  }

  /// Repeated on every segment turn, not only in the system prompt. The
  /// observed failure is occasional, appearing partway through a session
  /// rather than at its start, which is the signature of drift across a long
  /// conversation rather than of the instruction being missed outright.
  /// Repeated every turn for the same reason as [_englishOnlyReminder]: a rule
  /// stated once in the system prompt drifts as the conversation grows, and
  /// counted breathing is what the model falls back to by default.
  static const String _noCountingReminder =
      'Guide the breath without counting: no numerals and no number words for '
      'breath timing. ';

  static const String _englishOnlyReminder =
      'Write the instruction in English only; no Chinese or other non-Latin '
      'characters.';
}

class _Fallback {
  static const welcome =
      "Welcome. I'm here to guide you through a calming meditation. "
      "Let's begin together.";

  static const completion =
      "Wonderful work. You have taken a meaningful step towards calm. "
      "Carry this peace with you.";

  static const _segmentText =
      'Take a deep breath in... hold gently for a moment... and slowly '
      'release. Feel the tension melting away with each exhale. Your body is '
      'becoming more relaxed... your mind more peaceful. Continue breathing '
      'naturally... finding your center... allowing calmness to flow through '
      'you.';

  static MeditationSegment segment(int id, Duration? duration) {
    return MeditationSegment(
      segmentId: id,
      instruction: _segmentText,
      durationSeconds: duration?.inSeconds ??
          OverallMeditationConfig.standardNarrationMinimumDuration.inSeconds,
    );
  }
}
