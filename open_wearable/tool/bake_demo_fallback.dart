// Turns the captured demo narration into the Dart constants the app falls back
// to when DeepSeek cannot be reached.
//
// The two halves of that pipeline are both committed, so the backup text can be
// reviewed as a diff and rebuilt without guesswork:
//
//   1. capture   flutter test test/apps/meditation_app/demo_fallback_generator_test.dart
//                  --dart-define=GENERATE_DEMO_FALLBACK=true
//                writes tool/demo_fallback.json by running the real demo prompts
//   2. bake      dart run tool/bake_demo_fallback.dart
//                writes lib/apps/meditation_app/model/demo_fallback_script.dart
//
// Run `dart format` on the result afterwards; this only wraps the long strings.

import 'dart:convert';
import 'dart:io';

const _source = 'tool/demo_fallback.json';
const _target = 'lib/apps/meditation_app/model/demo_fallback_script.dart';

/// Must match the order of `MeditationType.values`.
const _types = [
  'mindfulness',
  'breathing',
  'bodyScan',
  'visualizationJourney',
];

/// Must match the order of `MeditationEnvironment.values`.
const _environments = ['ocean', 'mountain', 'forest', 'garden'];

void main() {
  final file = File(_source);
  if (!file.existsSync()) {
    stderr.writeln('Missing $_source. Run the capture step first.');
    exitCode = 1;
    return;
  }

  final captured = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  final buffer = StringBuffer(_header);
  for (final type in _types) {
    buffer.writeln('    MeditationType.$type: {');
    for (final environment in _environments) {
      final entry = captured['$type/$environment'] as Map<String, dynamic>?;
      if (entry == null) {
        stderr.writeln('Missing capture for $type/$environment.');
        exitCode = 1;
        return;
      }
      final segments = (entry['segments'] as List).cast<String>();
      buffer.writeln('      MeditationEnvironment.$environment: _DemoScript(');
      buffer.writeln(
        '        welcome: ${_dartString(entry['welcome'] as String, 10)},',
      );
      buffer.writeln(
        '        completion: '
        '${_dartString(entry['completion'] as String, 10)},',
      );
      buffer.writeln('        segments: [');
      for (final segment in segments) {
        buffer.writeln('          ${_dartString(segment, 10)},');
      }
      buffer.writeln('        ],');
      buffer.writeln('      ),');
    }
    buffer.writeln('    },');
  }
  buffer.write(_footer);

  File(_target).writeAsStringSync(buffer.toString());
  stdout.writeln(
    'Wrote $_target from ${captured.length} captured combinations.',
  );
}

/// One narration as adjacent single-quoted Dart literals, wrapped on word
/// boundaries so the generated file stays readable in review.
String _dartString(String text, int indent) {
  final escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ');

  final width = 72 - indent;
  final lines = <String>[];
  var current = StringBuffer();
  for (final word in escaped.split(' ')) {
    if (current.isEmpty) {
      current.write(word);
    } else if (current.length + 1 + word.length <= width) {
      current.write(' $word');
    } else {
      lines.add(current.toString());
      current = StringBuffer(word);
    }
  }
  if (current.isNotEmpty) lines.add(current.toString());

  final padding = ' ' * indent;
  return [
    for (var i = 0; i < lines.length; i++)
      '${i == 0 ? '' : padding}'
          "'${lines[i]}${i == lines.length - 1 ? '' : ' '}'",
  ].join('\n');
}

const _header = '''import '../configs/overall_config.dart';
import 'meditation_session_generator.dart' show MeditationSegment;
import 'user_account.dart';

// GENERATED FILE - do not edit by hand.
// Rebuild with: dart run tool/bake_demo_fallback.dart
// Source text: tool/demo_fallback.json

/// Pre-written demo narration for when DeepSeek cannot be reached.
///
/// The conference demo is the one place where a failed generation cannot be
/// recovered by trying again later: an attendee is already wearing the
/// earbuds. The regular and timed modes keep the single generic fallback
/// paragraph, which is fine for a session a user can simply restart.
///
/// These texts were not written by hand. They were captured from DeepSeek
/// itself, by driving `AdaptiveMeditationScript` with the real conference-demo
/// prompts once per attendee combination, so a fallback session reads exactly
/// like a live one. Both halves of that pipeline are committed: the captured
/// text in `tool/demo_fallback.json`, and the two steps that produce this file
/// in `test/apps/meditation_app/demo_fallback_generator_test.dart` and
/// `tool/bake_demo_fallback.dart`.
///
/// They are Dart constants rather than a bundled asset on purpose: this is the
/// path taken when things are already failing, and a constant cannot fail to
/// load, parse, or be left out of a build.
///
/// Coverage is every combination an attendee can select - four meditation
/// types by four environments - each with its own welcome, completion and
/// three segments. Speaking speed and voice gender are delivery settings
/// applied by the voice provider, so they need no separate copy.
abstract final class DemoFallbackScript {
  /// The opening line for the attendee's chosen session.
  static String welcomeFor(UserAccount account) => _scriptFor(account).welcome;

  /// The closing line. Generated alongside the segments, so it matches their
  /// wording, and usable from wherever the session stopped.
  static String completionFor(UserAccount account) =>
      _scriptFor(account).completion;

  /// The narration for segment [index], counting from one.
  ///
  /// Indices past the written three wrap around, so raising the demo segment
  /// cap keeps producing usable narration instead of running out.
  static String segmentText({
    required int index,
    MeditationType? type,
    MeditationEnvironment? environment,
  }) {
    final segments = _lookup(type, environment).segments;
    return segments[(index - 1) % segments.length];
  }

  /// [segmentText] as a segment the session can play directly.
  static MeditationSegment segmentFor({
    required UserAccount account,
    required int index,
    Duration? duration,
  }) {
    return MeditationSegment(
      segmentId: index,
      instruction: segmentText(
        index: index,
        type: account.meditationType,
        environment: account.meditationEnvironment,
      ),
      durationSeconds: (duration ??
              OverallMeditationConfig.standardNarrationMinimumDuration)
          .inSeconds,
    );
  }

  static _DemoScript _scriptFor(UserAccount account) =>
      _lookup(account.meditationType, account.meditationEnvironment);

  /// An attendee who never opened the preferences still gets a full script.
  static _DemoScript _lookup(
    MeditationType? type,
    MeditationEnvironment? environment,
  ) =>
      _scripts[type ?? MeditationType.mindfulness]![
          environment ?? MeditationEnvironment.forest]!;

  static const Map<MeditationType, Map<MeditationEnvironment, _DemoScript>>
      _scripts = {
''';

const _footer = '''  };
}

/// One captured session: what the demo would have said for this combination.
class _DemoScript {
  final String welcome;
  final String completion;
  final List<String> segments;

  const _DemoScript({
    required this.welcome,
    required this.completion,
    required this.segments,
  });
}
''';
