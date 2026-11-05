// Covers the pre-written demo narration used when DeepSeek cannot be reached:
// that it is complete for every attendee choice, that only the demo uses it,
// and that each of the three ways generation can fail reaches it.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_wearable/apps/meditation_app/configs/demo_mode_config.dart';
import 'package:open_wearable/apps/meditation_app/model/demo_fallback_script.dart';
import 'package:open_wearable/apps/meditation_app/model/meditation_prompt_policy.dart';
import 'package:open_wearable/apps/meditation_app/model/meditation_session_generator.dart';
import 'package:open_wearable/apps/meditation_app/model/user_account.dart';

void main() {
  UserAccount demoAccount({
    MeditationType? type,
    MeditationEnvironment? environment,
  }) =>
      UserAccount(
        meditationType: type,
        meditationEnvironment: environment,
        deepseekApiKey: 'test-key',
      )..hasValidDeepseekKey = true;

  group('demo backup narration', () {
    test('covers every meditation type and environment an attendee can pick',
        () {
      final seen = <String>{};

      for (final type in MeditationType.values) {
        for (final environment in MeditationEnvironment.values) {
          for (var index = 1;
              index <= DemoModeConfig.biosignalAdaptiveMeditationSegmentCount;
              index++) {
            final text = DemoFallbackScript.segmentText(
              index: index,
              type: type,
              environment: environment,
            );

            // No unfilled slot may reach an attendee's ears.
            expect(text, isNot(contains('{')));
            expect(text, isNot(contains('}')));
            expect(text.length, greaterThan(120));
            seen.add(text);
          }
        }
      }

      // 4 types x 4 environments x 3 segments, all distinct.
      expect(seen, hasLength(48));
    });

    test('the narration never counts the breath out', () {
      // Counted cadence ("in for 4, out for 6") is what the prompts used to
      // demand. Numerals read especially badly on the local voice, which
      // speaks them as digits instead of pacing them.
      final digits = RegExp(r'[0-9]');
      // The check itself catches what it is meant to.
      expect(digits.hasMatch('breathe in for 4 counts'), isTrue);

      for (final type in MeditationType.values) {
        for (final environment in MeditationEnvironment.values) {
          final account = UserAccount(
            meditationType: type,
            meditationEnvironment: environment,
          );
          final spoken = [
            DemoFallbackScript.welcomeFor(account),
            DemoFallbackScript.completionFor(account),
            for (var i = 1; i <= 3; i++)
              DemoFallbackScript.segmentText(
                index: i,
                type: type,
                environment: environment,
              ),
          ];

          for (final text in spoken) {
            expect(
              digits.hasMatch(text),
              isFalse,
              reason: '$type in $environment speaks a numeral: $text',
            );
            expect(
              text.toLowerCase(),
              isNot(contains('count')),
              reason: '$type in $environment counts the breath: $text',
            );
          }
        }
      }
    });

    test('each combination carries its own environment imagery', () {
      // The texts came from DeepSeek, so assert the property rather than any
      // particular wording: every environment reads differently, and each
      // session mentions the scenery the attendee asked for somewhere.
      const vocabulary = {
        MeditationEnvironment.ocean: ['ocean', 'sea', 'wave', 'shore', 'tide'],
        MeditationEnvironment.mountain: ['mountain', 'peak', 'ridge', 'summit'],
        MeditationEnvironment.forest: ['forest', 'tree', 'wood', 'leaf'],
        MeditationEnvironment.garden: ['garden', 'flower', 'petal', 'bloom'],
      };

      for (final type in MeditationType.values) {
        final openings = <String>{};
        for (final environment in MeditationEnvironment.values) {
          final account = UserAccount(
            meditationType: type,
            meditationEnvironment: environment,
          );
          final session = [
            DemoFallbackScript.welcomeFor(account),
            DemoFallbackScript.completionFor(account),
            for (var i = 1; i <= 3; i++)
              DemoFallbackScript.segmentText(
                index: i,
                type: type,
                environment: environment,
              ),
          ].join(' ').toLowerCase();

          expect(
            vocabulary[environment]!.any(session.contains),
            isTrue,
            reason: '$type in $environment never mentions its surroundings',
          );
          openings.add(
            DemoFallbackScript.segmentText(
              index: 1,
              type: type,
              environment: environment,
            ),
          );
        }
        expect(openings, hasLength(MeditationEnvironment.values.length));
      }
    });

    test('every combination has a welcome and a completion', () {
      for (final type in MeditationType.values) {
        for (final environment in MeditationEnvironment.values) {
          final account = UserAccount(
            meditationType: type,
            meditationEnvironment: environment,
          );
          expect(DemoFallbackScript.welcomeFor(account), isNotEmpty);
          expect(DemoFallbackScript.completionFor(account), isNotEmpty);
        }
      }
    });

    test('an attendee who never opened the preferences still gets a script',
        () {
      final untouched = UserAccount();
      expect(DemoFallbackScript.welcomeFor(untouched), isNotEmpty);
      expect(DemoFallbackScript.completionFor(untouched), isNotEmpty);
      expect(DemoFallbackScript.segmentText(index: 1), isNotEmpty);
    });

    test('a raised segment cap keeps producing narration', () {
      // The demo caps at three, but the count is configuration; running past
      // the written bodies must wrap rather than fail.
      final fourth = DemoFallbackScript.segmentText(
        index: 4,
        type: MeditationType.mindfulness,
      );
      final first = DemoFallbackScript.segmentText(
        index: 1,
        type: MeditationType.mindfulness,
      );
      expect(fourth, first);
    });
  });

  group('choosing the backup script', () {
    test('a demo without a key gets narration for its own preferences',
        () async {
      final account = UserAccount(
        meditationType: MeditationType.bodyScan,
        meditationEnvironment: MeditationEnvironment.mountain,
      );

      final script = createMeditationScript(
        account: account,
        maxSegments: DemoModeConfig.biosignalAdaptiveMeditationSegmentCount,
        segmentDuration: DemoModeConfig.meditationSegmentDuration,
        promptPolicy: MeditationPromptPolicy.conferenceDemo,
      );
      addTearDown(script.dispose);

      final opening = await script.begin();
      expect(opening.welcomeMessage, DemoFallbackScript.welcomeFor(account));
      expect(
        opening.firstSegment.instruction,
        DemoFallbackScript.segmentText(
          index: 1,
          type: MeditationType.bodyScan,
          environment: MeditationEnvironment.mountain,
        ),
      );
      expect(
        opening.completionMessage,
        DemoFallbackScript.completionFor(account),
      );
      expect(
        opening.firstSegment.durationSeconds,
        DemoModeConfig.meditationSegmentDuration.inSeconds,
      );

      final second = await script.nextSegment(null);
      final third = await script.nextSegment(null);
      expect(second, isNotNull);
      expect(third, isNotNull);
      expect(second!.instruction, isNot(third!.instruction));
      // Three segments, then the script is done.
      expect(await script.nextSegment(null), isNull);
    });

    test('regular and timed sessions keep the generic fallback', () {
      final account = UserAccount(
        meditationType: MeditationType.bodyScan,
        meditationEnvironment: MeditationEnvironment.mountain,
      );

      final script = createFallbackScript(
        account: account,
        maxSegments: 3,
      );
      addTearDown(script.dispose);

      expect(
        script.begin().then((frame) => frame.welcomeMessage),
        completion(isNot(contains('body'))),
      );
    });

    test('a failed opening request falls back to the demo script', () async {
      // begin() throws, which is what Meditation._run catches before building
      // the fallback script itself.
      final script = AdaptiveMeditationScript(
        account: demoAccount(
          type: MeditationType.visualizationJourney,
          environment: MeditationEnvironment.garden,
        ),
        maxSegments: 3,
        segmentDuration: DemoModeConfig.meditationSegmentDuration,
        promptPolicy: MeditationPromptPolicy.conferenceDemo,
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      addTearDown(script.dispose);

      await expectLater(script.begin(), throwsA(isA<Object>()));

      final fallback = createFallbackScript(
        account: demoAccount(
          type: MeditationType.visualizationJourney,
          environment: MeditationEnvironment.garden,
        ),
        maxSegments: 3,
        segmentDuration: DemoModeConfig.meditationSegmentDuration,
        promptPolicy: MeditationPromptPolicy.conferenceDemo,
      );
      addTearDown(fallback.dispose);

      final opening = await fallback.begin();
      expect(opening.welcomeMessage, contains('journey'));
      expect(opening.firstSegment.instruction, contains('garden'));
    });

    test('a segment request that fails mid-demo uses the written segment',
        () async {
      // The opening succeeds, then generation stops working. The session must
      // continue with narration matching the attendee's choices.
      var requests = 0;
      final script = AdaptiveMeditationScript(
        account: demoAccount(
          type: MeditationType.breathing,
          environment: MeditationEnvironment.ocean,
        ),
        maxSegments: 3,
        segmentDuration: DemoModeConfig.meditationSegmentDuration,
        promptPolicy: MeditationPromptPolicy.conferenceDemo,
        client: MockClient((_) async {
          requests++;
          if (requests > 1) return http.Response('upstream is down', 503);
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'welcomeMessage': 'Hello.',
                      'completionMessage': 'Goodbye.',
                      'segment': {
                        'segmentId': 1,
                        'instruction': 'Generated first segment.',
                      },
                    }),
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(script.dispose);

      final opening = await script.begin();
      expect(opening.firstSegment.instruction, 'Generated first segment.');

      final second = await script.nextSegment(null);
      expect(second, isNotNull);
      expect(second!.instruction, contains('wave'));
      expect(
        second.durationSeconds,
        DemoModeConfig.meditationSegmentDuration.inSeconds,
      );
    });

    test('a failed segment outside the demo keeps the generic text', () async {
      final script = AdaptiveMeditationScript(
        account: UserAccount(
          meditationType: MeditationType.breathing,
          meditationEnvironment: MeditationEnvironment.ocean,
          deepseekApiKey: 'test-key',
        )..hasValidDeepseekKey = true,
        maxSegments: 3,
        client: MockClient((_) async => http.Response('down', 503)),
      );
      addTearDown(script.dispose);

      final segment = await script.nextSegment(null);
      expect(segment, isNotNull);
      expect(segment!.instruction, isNot(contains('wave')));
      expect(segment.instruction, contains('Take a deep breath in'));
    });
  });
}
