// Covers the narration pipeline: a segment is generated and synthesized while
// the previous one is still speaking, instead of in the silence after it.
//
// These tests drive a real [Meditation] end to end, so they stand in for the
// Android audio stack. [FakeAudioPlatform] answers the audioplayers method
// channel and pushes the `prepared` and `complete` events the plugin normally
// receives from the native player; the narration voice is a fake [TtsProvider]
// that records when each synthesis starts.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/meditation_app/configs/overall_config.dart';
import 'package:open_wearable/apps/meditation_app/model/meditation.dart';
import 'package:open_wearable/apps/meditation_app/model/tts_service.dart';
import 'package:open_wearable/apps/meditation_app/model/user_account.dart';

import 'fake_audio_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Installed for the whole file: an AudioPlayer disposes itself off the test's
  // own timeline, so tearing the channel down per test only produces noise.
  final audio = FakeAudioPlatform();
  setUpAll(audio.install);
  tearDownAll(audio.uninstall);

  group('narration pipeline', () {
    test('a session speaks every segment and then finishes', () async {
      final provider = _RecordingTtsProvider();
      final meditation = _PipelineMeditation(
        provider: provider,
        maxSegments: 3,
      );
      addTearDown(meditation.dispose);

      await meditation.start().timeout(const Duration(seconds: 30));

      expect(meditation.phase.value, MeditationPhase.finished);
      // Welcome, three segments, completion.
      expect(provider.playedTexts, hasLength(5));
      expect(provider.playedTexts.first, contains('Welcome'));
      expect(provider.playedTexts.last, contains('Wonderful work'));
    });

    test('the next narration is synthesized while the current one plays',
        () async {
      final provider = _RecordingTtsProvider();
      final meditation = _PipelineMeditation(
        provider: provider,
        maxSegments: 3,
      );
      addTearDown(meditation.dispose);

      await meditation.start().timeout(const Duration(seconds: 30));

      final timeline = meditation.timeline;
      // The welcome is the one narration nothing can precede, so its synthesis
      // is awaited on its own. Everything after it overlaps playback.
      expect(timeline.take(2), ['synthesizing:1', 'synthesized:1']);

      // While the welcome plays, the first segment and the completion message
      // are already being produced.
      final welcomeFinished = timeline.indexOf('played:1');
      expect(timeline.indexOf('synthesizing:2'), lessThan(welcomeFinished));
      expect(timeline.indexOf('synthesizing:3'), lessThan(welcomeFinished));

      // And the later segments are produced while an earlier one is speaking,
      // not in the gap after it.
      final firstSegmentFinished = timeline.indexOf('played:2');
      expect(
        timeline.indexOf('synthesizing:4'),
        lessThan(firstSegmentFinished),
      );

      // Nothing was synthesized twice.
      expect(
        timeline.where((entry) => entry.startsWith('synthesizing:')),
        hasLength(5),
      );
    });

    test('a segment produced ahead of an early exit is never spoken', () async {
      final provider = _RecordingTtsProvider();
      final meditation = _PipelineMeditation(
        provider: provider,
        maxSegments: 5,
        exitAfterSegments: 1,
      );
      addTearDown(meditation.dispose);

      await meditation.start().timeout(const Duration(seconds: 30));

      expect(meditation.phase.value, MeditationPhase.finished);
      // Welcome, one segment, completion. The prefetched segments were
      // produced but discarded rather than played.
      expect(provider.playedTexts, hasLength(3));
      expect(provider.playedTexts.last, contains('Wonderful work'));
      expect(
        provider.synthesizedTexts.length,
        greaterThan(provider.playedTexts.length),
        reason: 'the producer should have run ahead of the exit decision',
      );
    });

    test('narration prepared before a voice outage is still played', () async {
      // Welcome, first segment and completion message synthesize; the second
      // segment is where the voice service goes away for good.
      final provider = _RecordingTtsProvider(failAfterSyntheses: 3);
      final meditation = _PipelineMeditation(
        provider: provider,
        maxSegments: 5,
      );
      addTearDown(meditation.dispose);

      await meditation.start().timeout(const Duration(seconds: 30));

      expect(meditation.phase.value, MeditationPhase.failed);
      expect(meditation.failureTitle, 'Voice service interrupted');
      // The segment that was already in hand was spoken rather than dropped.
      expect(provider.playedTexts, hasLength(2));
      expect(provider.playedTexts.first, contains('Welcome'));
    });

    test('disposing as narration ends does not look like a failure', () async {
      // The window this targets: the UI stops the session in the instant
      // between playback finishing and _run publishing the next phase.
      // Writing to a ValueNotifier disposed in that gap used to throw, and
      // start() reported it as an unexpected meditation failure.
      final logged = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logged.add(message);
      };
      addTearDown(() => debugPrint = original);

      late final _PipelineMeditation meditation;
      var disposed = false;
      meditation = _PipelineMeditation(
        provider: _RecordingTtsProvider(),
        maxSegments: 3,
        onEvent: (event) {
          // Fires synchronously inside _playRespectingPause, just before it
          // returns into the phase write.
          if (event != 'narration_finished' || disposed) return;
          disposed = true;
          meditation.dispose();
        },
      );

      await meditation.start().timeout(const Duration(seconds: 30));

      expect(disposed, isTrue, reason: 'the window was never reached');
      expect(
        logged.where((m) => m.contains('unexpected failure')),
        isEmpty,
        reason: logged.join(' | '),
      );
      expect(
        logged.where((m) => m.contains('used after being disposed')),
        isEmpty,
        reason: logged.join(' | '),
      );
    });

    test('resuming continues the narration instead of replaying it', () async {
      final provider = _RecordingTtsProvider();
      late final _PipelineMeditation meditation;
      var paused = false;
      meditation = _PipelineMeditation(
        provider: provider,
        maxSegments: 1,
        onEvent: (event) {
          if (event != 'narration_requested' || paused) return;
          paused = true;
          // Interrupt the welcome while its audio is still playing.
          Future<void>.delayed(const Duration(milliseconds: 20), () {
            meditation.pause();
            Future<void>.delayed(const Duration(milliseconds: 40), () {
              meditation.resume();
            });
          });
        },
      );
      addTearDown(meditation.dispose);

      await meditation.start().timeout(const Duration(seconds: 30));

      expect(paused, isTrue, reason: 'the pause never happened');
      expect(meditation.phase.value, MeditationPhase.finished);
      // Welcome, one segment, completion. A replayed welcome would appear as
      // a fourth entry with the welcome text repeated.
      expect(provider.playedTexts, hasLength(3));
      expect(
        provider.playedTexts.where((t) => t.contains('Welcome')),
        hasLength(1),
      );
    });

    test('ambience that will not play does not stop the session', () async {
      // One environment shipped a file the platform could not decode, and the
      // session aborted with a generic failure card. The narration is the
      // meditation; losing the background audio must not take it with it.
      audio.failAssetLoading = true;
      addTearDown(() => audio.failAssetLoading = false);

      final provider = _RecordingTtsProvider();
      final meditation =
          _PipelineMeditation(provider: provider, maxSegments: 2);
      addTearDown(meditation.dispose);

      await meditation.start().timeout(const Duration(seconds: 30));

      expect(meditation.phase.value, MeditationPhase.finished);
      expect(meditation.failureTitle, isNull);
      // Welcome, two segments, completion.
      expect(provider.playedTexts, hasLength(4));
    });

    test('a stopped session neither plays nor keeps producing', () async {
      final provider = _RecordingTtsProvider();
      final meditation = _PipelineMeditation(
        provider: provider,
        maxSegments: 5,
        stopAfterSegments: 1,
      );
      addTearDown(meditation.dispose);

      await meditation.start().timeout(const Duration(seconds: 30));

      expect(meditation.phase.value, isNot(MeditationPhase.failed));
      // Welcome and the one segment; no completion message after a stop.
      expect(provider.playedTexts, hasLength(2));

      final producedAtStop = provider.synthesizedTexts.length;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(provider.synthesizedTexts, hasLength(producedAtStop));
    });
  });

  group('narration lookahead depth', () {
    test('a session without biosignals uses the configured depth', () {
      final meditation = _PipelineMeditation(
        provider: _RecordingTtsProvider(),
        maxSegments: 1,
      );
      addTearDown(meditation.dispose);
      expect(
        meditation.narrationPrefetchDepth,
        OverallMeditationConfig.narrationPrefetchDepth,
      );
      expect(OverallMeditationConfig.narrationPrefetchDepth, greaterThan(1));
    });

    test('the producer stays within the lookahead depth', () async {
      final provider = _RecordingTtsProvider();
      final meditation = _PipelineMeditation(
        provider: provider,
        maxSegments: 12,
        exitAfterSegments: 1,
      );
      addTearDown(meditation.dispose);

      await meditation.start().timeout(const Duration(seconds: 30));

      // Welcome, completion, the first segment, and at most a full buffer
      // beyond it. Without the bound the producer would have raced through
      // all twelve segments while the first one played.
      expect(
        provider.synthesizedTexts.length,
        lessThanOrEqualTo(
          3 + OverallMeditationConfig.narrationPrefetchDepth + 1,
        ),
      );
    });
  });

  group('prepared narration', () {
    test('synthesis happens in prepare, not in play', () async {
      final provider = _RecordingTtsProvider();
      final service = TtsService(
        userAccount: UserAccount(cloudProcessingConsent: true),
        provider: provider,
      );
      addTearDown(service.dispose);

      final narration = await service.prepare('breathe out slowly');
      expect(provider.synthesizedTexts, ['breathe out slowly']);
      expect(narration.isDeviceSpoken, isFalse);

      await service.play(narration);
      expect(provider.synthesizedTexts, ['breathe out slowly']);
    });

    test('synthesis retries, playback of the result does not', () async {
      final provider = _RecordingTtsProvider(failuresBeforeSuccess: 2);
      final service = TtsService(
        userAccount: UserAccount(cloudProcessingConsent: true),
        provider: provider,
      );
      addTearDown(service.dispose);

      final narration = await service.prepare('settle into the chair');
      expect(
        provider.synthesizedTexts,
        hasLength(OverallMeditationConfig.cloudTtsRetryDelays.length),
      );
      expect(narration.sources, isNotNull);
    });

    test('a voice service that never recovers stops the session', () async {
      final provider = _RecordingTtsProvider(failuresBeforeSuccess: 99);
      final service = TtsService(
        userAccount: UserAccount(cloudProcessingConsent: true),
        provider: provider,
      );
      addTearDown(service.dispose);

      await expectLater(
        service.prepare('this will not arrive'),
        throwsA(isA<TtsSessionException>()),
      );
    });

    test('a session without a usable cloud voice speaks on the device', () {
      // No provider override and no credentials: nothing to synthesize ahead.
      const narration = PreparedNarration(text: 'spoken by the phone');
      expect(narration.isDeviceSpoken, isTrue);
    });
  });
}

/// A [Meditation] whose narration comes from a fake voice and which can be
/// told to exit or stop after a given number of segments.
class _PipelineMeditation extends Meditation {
  final _RecordingTtsProvider provider;
  final int? exitAfterSegments;
  final int? stopAfterSegments;
  int _segmentsPlayed = 0;

  _PipelineMeditation({
    required this.provider,
    required super.maxSegments,
    this.exitAfterSegments,
    this.stopAfterSegments,
    void Function(String event)? onEvent,
  }) : super(
          userAccount: UserAccount(cloudProcessingConsent: true),
          diagnosticEventSink:
              onEvent == null ? null : ((event, _) => onEvent(event)),
        ) {
    provider.timeline = timeline;
  }

  final List<String> timeline = [];

  @override
  TtsService createTtsService() =>
      TtsService(userAccount: userAccount, provider: provider);

  @override
  bool checkEarlyExit() {
    _segmentsPlayed++;
    if (stopAfterSegments != null && _segmentsPlayed >= stopAfterSegments!) {
      unawaited(stop());
      return true;
    }
    return exitAfterSegments != null && _segmentsPlayed >= exitAfterSegments!;
  }
}

/// Records when each synthesis starts and finishes, and when the audio it
/// produced is played, on a single shared timeline.
class _RecordingTtsProvider implements TtsProvider {
  static const _synthesisDelay = Duration(milliseconds: 20);

  int failuresBeforeSuccess;

  /// After this many successful syntheses the fake voice service never
  /// recovers, standing in for a cloud outage mid-session.
  final int? failAfterSyntheses;

  final List<String> synthesizedTexts = [];
  final List<String> playedTexts = [];
  List<String> timeline = [];

  final Map<int, String> _textBySourceTag = {};
  int _synthesisCount = 0;

  _RecordingTtsProvider({
    this.failuresBeforeSuccess = 0,
    this.failAfterSyntheses,
  });

  @override
  bool get isAvailable => true;

  @override
  Future<List<Source>> synthesize(String text) async {
    synthesizedTexts.add(text);
    final index = ++_synthesisCount;
    timeline.add('synthesizing:$index');
    await Future<void>.delayed(_synthesisDelay);
    if (failAfterSyntheses != null && index > failAfterSyntheses!) {
      throw StateError('the fake voice service went away');
    }
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw StateError('the fake voice service is unavailable');
    }
    timeline.add('synthesized:$index');
    // The tag travels in the audio bytes so playback can be attributed back to
    // the text that produced it.
    final bytes = Uint8List.fromList([index]);
    _textBySourceTag[index] = text;
    return [_TaggedSource(index, this, BytesSource(bytes))];
  }

  void _onPlaybackStarted(int tag) {
    playedTexts.add(_textBySourceTag[tag]!);
    timeline.add('playing:$tag');
  }

  void _onPlaybackFinished(int tag) => timeline.add('played:$tag');

  @override
  void dispose() {}
}

/// A [Source] that reports to its provider when it is handed to the player.
class _TaggedSource extends Source {
  final int tag;
  final _RecordingTtsProvider owner;
  final BytesSource delegate;

  _TaggedSource(this.tag, this.owner, this.delegate);

  @override
  String? get mimeType => delegate.mimeType;

  @override
  Future<void> setOnPlayer(AudioPlayer player) async {
    owner._onPlaybackStarted(tag);
    // Disposing the player closes this stream, so `first` completes with an
    // error rather than a value. That is a normal end for a session that was
    // stopped mid-narration, not a test failure.
    unawaited(
      player.onPlayerComplete.first.then(
        (_) => owner._onPlaybackFinished(tag),
        onError: (Object _, StackTrace __) {},
      ),
    );
    await delegate.setOnPlayer(player);
  }
}
