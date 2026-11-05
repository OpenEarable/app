// Offline generator for the demo's backup narration. Not a test: it is skipped
// unless explicitly enabled, and it talks to DeepSeek.
//
// It drives the app's own AdaptiveMeditationScript with the conference-demo
// prompt policy, so the text it captures is exactly what a live demo would
// have produced for that attendee's choices. The captured JSON is then baked
// into lib/apps/meditation_app/model/demo_fallback_script.dart, which is what
// the app falls back to when DeepSeek cannot be reached.
//
// Run from open_wearable/ with DEEPSEEK_API_KEY set in the shell environment:
//
//   flutter test test/apps/meditation_app/demo_fallback_generator_test.dart ^
//     --dart-define=GENERATE_DEMO_FALLBACK=true
//
// It writes tool/demo_fallback.json, which is committed so the backup text can
// be reviewed as a diff. Bake it into Dart afterwards with:
//
//   dart run tool/bake_demo_fallback.dart
//
// Regenerate only when the demo prompts or the selectable preferences change.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/meditation_app/configs/demo_mode_config.dart';
import 'package:open_wearable/apps/meditation_app/model/meditation_prompt_policy.dart';
import 'package:open_wearable/apps/meditation_app/model/meditation_session_generator.dart';
import 'package:open_wearable/apps/meditation_app/model/user_account.dart';

const _enabled = bool.fromEnvironment('GENERATE_DEMO_FALLBACK');

/// How many attendee combinations are generated at once. The three requests
/// within one combination must stay sequential: each segment is conditioned on
/// the conversation so far.
const _concurrency = 4;

void main() {
  test(
    'generates demo backup narration for every attendee combination',
    () async {
      final apiKey = Platform.environment['DEEPSEEK_API_KEY']?.trim() ?? '';
      expect(
        apiKey,
        isNotEmpty,
        reason: 'DEEPSEEK_API_KEY is not set in the shell environment',
      );

      final combinations = [
        for (final type in MeditationType.values)
          for (final environment in MeditationEnvironment.values)
            (type: type, environment: environment),
      ];

      final results = <String, Map<String, Object?>>{};
      for (var start = 0; start < combinations.length; start += _concurrency) {
        final batch = combinations.skip(start).take(_concurrency);
        await Future.wait(
          batch.map((combination) async {
            final script = await _generateOne(
              apiKey: apiKey,
              type: combination.type,
              environment: combination.environment,
            );
            final id =
                '${combination.type.name}/${combination.environment.name}';
            results[id] = script;
            // ignore: avoid_print
            print('done $id');
          }),
        );
      }

      final output = File('tool/demo_fallback.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert(results),
      );
      // ignore: avoid_print
      print('wrote ${output.path} with ${results.length} combinations');
      // ignore: avoid_print
      print('now run: dart run tool/bake_demo_fallback.dart');

      expect(
        results,
        hasLength(
          MeditationType.values.length * MeditationEnvironment.values.length,
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 30)),
    skip: _enabled ? false : 'set --dart-define=GENERATE_DEMO_FALLBACK=true',
  );
}

Future<Map<String, Object?>> _generateOne({
  required String apiKey,
  required MeditationType type,
  required MeditationEnvironment environment,
}) async {
  final segmentCount = DemoModeConfig.biosignalAdaptiveMeditationSegmentCount;
  final script = AdaptiveMeditationScript(
    account: UserAccount(
      meditationType: type,
      meditationEnvironment: environment,
      deepseekApiKey: apiKey,
    )..hasValidDeepseekKey = true,
    maxSegments: segmentCount,
    segmentDuration: DemoModeConfig.meditationSegmentDuration,
    promptPolicy: MeditationPromptPolicy.conferenceDemo,
  );

  try {
    final opening = await script.begin();
    final instructions = <String>[opening.firstSegment.instruction];
    while (instructions.length < segmentCount) {
      final next = await script.nextSegment(null);
      if (next == null) break;
      instructions.add(next.instruction);
    }

    return {
      'welcome': opening.welcomeMessage,
      'completion': opening.completionMessage,
      'segments': instructions,
    };
  } finally {
    script.dispose();
  }
}
