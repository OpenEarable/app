import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:collection';
import '../configs/bio_adaptive_mode_config.dart';
import '../configs/overall_config.dart';
import '../configs/timed_mode_config.dart';
import 'user_account.dart';
import 'measurement.dart';
import 'meditation_session_generator.dart';
import 'meditation_prompt_policy.dart';
import 'meditation_analytics.dart';
import 'hr_hrv_processor.dart' show HeartRateSample;
import 'tts_service.dart';

/// A generated segment together with its already-synthesized narration.
class _PreparedSegment {
  final MeditationSegment segment;
  final PreparedNarration narration;

  const _PreparedSegment({required this.segment, required this.narration});
}

enum MeditationPhase {
  preparing,
  welcome,
  segment,
  completion,
  failed,
  finished,
}

class Meditation {
  final UserAccount userAccount;
  AudioPlayer? _musicPlayer;
  TtsService? _ttsService;

  /// Both are created on first use. A scheduled meditation can sit for hours
  /// before it runs, and building them at construction time held a native
  /// audio player and a voice service - now possibly a loaded local model -
  /// for every meditation merely queued.
  AudioPlayer get musicPlayer => _musicPlayer ??= AudioPlayer();

  TtsService get ttsService => _ttsService ??= createTtsService();
  final int maxSegments;
  Duration? meditationSegmentDuration;
  final MeditationPromptPolicy promptPolicy;
  final MeditationAnalyticsStore? analyticsStore;
  final MeditationAnalyticsMode? analyticsMode;
  final void Function(String, Map<String, Object?>)? diagnosticEventSink;

  late final ValueNotifier<MeditationPhase> phase;
  String? failureTitle;
  String? failureMessage;

  bool isStopped = false;
  bool _isDisposed = false;
  final ValueNotifier<bool> isPaused = ValueNotifier<bool>(false);
  Completer<void>? _resumeCompleter;

  MeditationScript? _script;
  DateTime? _analyticsStartedAt;
  bool _analyticsRecorded = false;

  Meditation({
    required this.userAccount,
    this.maxSegments = OverallMeditationConfig.defaultSegmentCount,
    this.meditationSegmentDuration,
    this.promptPolicy = MeditationPromptPolicy.standard,
    this.analyticsStore,
    this.analyticsMode,
    this.diagnosticEventSink,
  }) : assert(
          (analyticsStore == null) == (analyticsMode == null),
          'Analytics store and mode must either both be set or both be null.',
        ) {
    phase = ValueNotifier<MeditationPhase>(MeditationPhase.preparing);
  }

  /// The narration route for this session, fixed for its whole duration.
  @protected
  TtsService createTtsService() => TtsService(userAccount: userAccount);

  /// Publishes a phase, unless this session has already been disposed.
  ///
  /// `_run` resumes after awaiting narration playback, and a stop from the UI
  /// disposes the session in between. Writing to a disposed ValueNotifier
  /// throws, and `start` would catch that and present it as an unexpected
  /// meditation failure, which is not what happened.
  void _setPhase(MeditationPhase next) {
    if (_isDisposed) return;
    phase.value = next;
  }

  // This method can be overridden in subclasses to implement early exit conditions.
  bool checkEarlyExit() => false;

  HeartRateSample? readCurrentBiometrics() => null;

  /// How many segments may be produced ahead of the one being played.
  ///
  /// Generation and speech synthesis both cost seconds that used to be silence
  /// between segments, so they now run while the previous segment is speaking.
  /// Sessions without biosignals can run further ahead because nothing they
  /// send depends on the moment the request is made.
  int get narrationPrefetchDepth =>
      OverallMeditationConfig.narrationPrefetchDepth;

  Future<void> start() async {
    if (_isDisposed) return;
    isStopped = false;
    _setPhase(MeditationPhase.preparing);
    failureTitle = null;
    failureMessage = null;
    _analyticsStartedAt = DateTime.now();
    _analyticsRecorded = false;

    try {
      await _run();
    } on TtsSessionException catch (error) {
      debugPrint('Meditation stopped after voice service failure: $error');
      await _fail(
        title: 'Voice service interrupted',
        message: 'The selected voice service became unavailable. The session '
            'was stopped rather than switching to a different voice. Check '
            'the network connection and try again.',
      );
    } catch (error, stackTrace) {
      debugPrint('Meditation stopped after an unexpected failure: $error');
      debugPrint('$stackTrace');
      await _fail(
        title: 'Meditation interrupted',
        message: 'The meditation could not continue. Please try again.',
      );
    }
  }

  Future<void> _run() async {
    // Start background music
    await _startBackgroundMusic();
    if (isStopped) return _endRun();

    // build meditation script
    _script = createMeditationScript(
      account: userAccount,
      maxSegments: maxSegments,
      segmentDuration: meditationSegmentDuration,
      promptPolicy: promptPolicy,
    );

    MeditationFrame opening;
    try {
      opening = await _script!.begin();
    } catch (e) {
      if (isStopped) {
        _endRun();
        return;
      }
      debugPrint('Error generating meditation opening: $e');
      _script!.dispose();
      _script = createFallbackScript(
        account: userAccount,
        maxSegments: maxSegments,
        segmentDuration: meditationSegmentDuration,
        promptPolicy: promptPolicy,
      );
      opening = await _script!.begin();
    }

    if (isStopped) return _endRun();

    // Speak the welcome message. Nothing precedes it, so this synthesis is the
    // one wait that cannot be overlapped.
    _setPhase(MeditationPhase.welcome);
    final welcome = await _prepareNarration(opening.welcomeMessage);
    if (isStopped) return _endRun();

    // Both of these are known already, so they are synthesized while the
    // welcome plays rather than in the silence that used to follow it.
    final firstSegment = _observed(_prepareSegment(opening.firstSegment));
    final completion = _observed(
      _prepareNarration(opening.completionMessage),
    );

    await _playRespectingPause(welcome);

    // Run through the meditation segments
    _setPhase(MeditationPhase.segment);
    await _runSegments(await firstSegment);

    // Speak the completion message
    if (isStopped) return _endRun();
    _setPhase(MeditationPhase.completion);
    await _playRespectingPause(await completion);

    // Mark the meditation as finished
    _setPhase(MeditationPhase.finished);
    _endRun();
    await _recordAnalytics(completed: true);
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    isStopped = true;
    _resumeCompleter?.complete();
    _resumeCompleter = null;

    await _stopPlayback();
    _endRun();
    await _recordAnalytics(completed: false);
  }

  void pause() {
    if (_isDisposed) return;
    isPaused.value = true;
    _resumeCompleter ??= Completer<void>();
    unawaited(_pausePlayback());
  }

  void resume() {
    if (_isDisposed) return;
    isPaused.value = false;
    final music = _musicPlayer;
    if (music != null) {
      unawaited(
        music.resume().catchError(
          (Object error, StackTrace stackTrace) {
            _logPlaybackError(
              'resuming background music',
              error,
              stackTrace,
            );
          },
        ),
      );
    }
    if (_ttsService?.canPauseNarration ?? false) {
      unawaited(
        ttsService.resume().catchError(
          (Object error, StackTrace stackTrace) {
            _logPlaybackError('resuming narration', error, stackTrace);
          },
        ),
      );
    }
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    isStopped = true;
    _resumeCompleter?.complete();
    _resumeCompleter = null;

    _endRun();
    final music = _musicPlayer;
    if (music != null) {
      unawaited(
        music.dispose().catchError(
          (Object error, StackTrace stackTrace) {
            _logPlaybackError(
              'disposing background music',
              error,
              stackTrace,
            );
          },
        ),
      );
    }
    _ttsService?.dispose();
    isPaused.dispose();
    phase.dispose();
    unawaited(_recordAnalytics(completed: false));
  }

  Future<void> _waitForResume() {
    _resumeCompleter ??= Completer<void>();
    return _resumeCompleter!.future;
  }

  /// Keeps a future's error from being reported as unhandled while it is
  /// produced ahead of the point where it is awaited.
  Future<T> _observed<T>(Future<T> future) {
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    return future;
  }

  Future<PreparedNarration> _prepareNarration(String text) =>
      ttsService.prepare(text);

  Future<_PreparedSegment> _prepareSegment(MeditationSegment segment) async {
    return _PreparedSegment(
      segment: segment,
      narration: await _prepareNarration(segment.instruction),
    );
  }

  Future<void> _playRespectingPause(PreparedNarration narration) async {
    while (true) {
      if (isPaused.value) await _waitForResume();
      if (isStopped) return;

      diagnosticEventSink?.call('narration_requested', {
        'characters': narration.text.length,
      });
      final startedAt = DateTime.now();
      try {
        await ttsService.play(narration);
        diagnosticEventSink?.call('narration_finished', {
          'played_ms': DateTime.now().difference(startedAt).inMilliseconds,
        });
      } catch (error) {
        diagnosticEventSink?.call('narration_failed', {
          'error_type': error.runtimeType.toString(),
        });
        rethrow;
      }
      if (!isPaused.value) return;
    }
  }

  Future<void> _startBackgroundMusic() async {
    // A debug-only A/B test for earbud audio/PPG transport contention. The
    // production meditation always retains its background music.
    if (kDebugMode &&
        const bool.fromEnvironment('MEDITATION_SKIP_BACKGROUND_MUSIC')) {
      diagnosticEventSink?.call('audio_skipped_for_diagnostics', const {});
      return;
    }
    diagnosticEventSink?.call('audio_start_requested', const {});
    try {
      musicPlayer.audioCache = AudioCache(
        prefix: OverallMeditationConfig.audioAssetPrefix,
      );
      await musicPlayer.setReleaseMode(ReleaseMode.loop);
      await musicPlayer
          .setVolume(OverallMeditationConfig.backgroundMusicVolume);
      await musicPlayer.play(
        AssetSource(
          userAccount.meditationEnvironment?.assetPath ??
              MeditationEnvironment.forest.assetPath,
        ),
      );
      diagnosticEventSink?.call('audio_started', const {});
    } catch (error, stackTrace) {
      diagnosticEventSink?.call('audio_start_failed', {
        'error_type': error.runtimeType.toString(),
      });
      // Ambience is atmosphere; the narration is the session. Rethrowing here
      // meant one environment whose file the device could not decode took the
      // whole meditation down with a generic "interrupted" card, with nothing
      // to say which part had failed.
      _logPlaybackError('starting background music', error, stackTrace);
    }
  }

  /// Plays segments while the ones after them are generated and synthesized.
  ///
  /// Producing the next segment used to begin only once the current one had
  /// stopped speaking, so its generation and synthesis time was silence the
  /// listener sat through. It now runs during playback instead.
  ///
  /// The decision to *play* a produced segment is still taken at the end of the
  /// previous one, against heart rate as before. A segment produced ahead of an
  /// early exit is simply discarded.
  Future<void> _runSegments(_PreparedSegment first) async {
    final buffer = Queue<_PreparedSegment>();
    final stopProducing = Completer<void>();
    var producerFinished = false;
    Object? producerError;
    StackTrace? producerStackTrace;

    // The two sides wake each other instead of only polling, so a segment that
    // arrives late still starts playing the moment it is ready. The poll
    // interval stays as a liveness backstop for stop() and dispose().
    Completer<void>? bufferFilled;
    Completer<void>? bufferDrained;
    void wake(Completer<void>? Function() read, void Function() clear) {
      final waiter = read();
      clear();
      if (waiter != null && !waiter.isCompleted) waiter.complete();
    }

    // One producer, because each generated segment depends on the conversation
    // history of the one before it and cannot be requested in parallel.
    final producer = _observed(
      () async {
        try {
          while (!isStopped && !_isDisposed && !stopProducing.isCompleted) {
            if (buffer.length >= narrationPrefetchDepth) {
              bufferDrained ??= Completer<void>();
              await Future.any([
                bufferDrained!.future,
                stopProducing.future,
                Future<void>.delayed(
                  OverallMeditationConfig.progressUpdateInterval,
                ),
              ]);
              continue;
            }
            // _endRun clears the script when the session finishes, and the
            // producer can still be between checks at that moment. Ending the
            // loop is the honest response; asserting non-null here turned a
            // normal shutdown into a caught TypeError.
            final script = _script;
            if (script == null) break;
            final segment = await script.nextSegment(readCurrentBiometrics());
            if (segment == null) break;
            if (isStopped || _isDisposed || stopProducing.isCompleted) break;
            buffer.add(await _prepareSegment(segment));
            wake(() => bufferFilled, () => bufferFilled = null);
          }
        } catch (error, stackTrace) {
          producerError = error;
          producerStackTrace = stackTrace;
        } finally {
          producerFinished = true;
          wake(() => bufferFilled, () => bufferFilled = null);
        }
      }(),
    );

    var current = first;
    while (!isStopped) {
      final segmentStart = DateTime.now();
      final segmentDuration =
          Duration(seconds: current.segment.durationSeconds);
      var pausedDuration = Duration.zero;

      await _playRespectingPause(current.narration);
      if (isStopped) break;

      // Hold out any remaining nominal segment time before moving on.
      while (true) {
        if (isPaused.value) {
          final pauseStart = DateTime.now();
          await _waitForResume();
          pausedDuration += DateTime.now().difference(pauseStart);
        }
        if (isStopped) break;
        final elapsed =
            DateTime.now().difference(segmentStart) - pausedDuration;
        if (elapsed >= segmentDuration) break;
        await Future.delayed(OverallMeditationConfig.progressUpdateInterval);
      }

      if (isStopped) break;
      if (checkEarlyExit()) break;

      // Wait for the producer only if it has not kept up.
      while (buffer.isEmpty && !producerFinished && !isStopped) {
        bufferFilled ??= Completer<void>();
        await Future.any([
          bufferFilled!.future,
          Future<void>.delayed(OverallMeditationConfig.progressUpdateInterval),
        ]);
      }
      if (isStopped) break;
      // Segments that were prepared before the producer failed are still good
      // and are played first, so a failure surfaces where the old sequential
      // code surfaced it: when the session actually runs out of narration.
      if (buffer.isNotEmpty) {
        current = buffer.removeFirst();
        wake(() => bufferDrained, () => bufferDrained = null);
        continue;
      }
      if (producerError != null) {
        _stopProducer(stopProducing);
        Error.throwWithStackTrace(
          producerError!,
          producerStackTrace ?? StackTrace.current,
        );
      }
      break;
    }

    // The session does not wait for a request that is already in flight: its
    // result has nowhere to go, and the closing narration should not be held
    // back by it. _endRun() disposes the script, which ends that request.
    _stopProducer(stopProducing);
    unawaited(producer);
  }

  static void _stopProducer(Completer<void> stopProducing) {
    if (!stopProducing.isCompleted) stopProducing.complete();
  }

  void _endRun() {
    final script = _script;
    _script = null;
    script?.dispose();
  }

  Future<void> _fail({
    required String title,
    required String message,
  }) async {
    isStopped = true;
    if (!_isDisposed) {
      failureTitle = title;
      failureMessage = message;
      _setPhase(MeditationPhase.failed);
    }
    await _stopPlayback();
    _endRun();
    await _recordAnalytics(completed: false);
  }

  Future<void> _pausePlayback() async {
    try {
      await _musicPlayer?.pause();
    } catch (error, stackTrace) {
      _logPlaybackError('pausing background music', error, stackTrace);
    }
    final narration = _ttsService;
    if (narration == null) return;
    try {
      // Suspending keeps the narration's position, so resuming continues the
      // segment instead of speaking it again from its first word. The device
      // fallback cannot resume, so that route is stopped and replayed by
      // _playRespectingPause.
      if (narration.canPauseNarration) {
        await narration.pause();
      } else {
        await narration.stop();
      }
    } catch (error, stackTrace) {
      _logPlaybackError('pausing narration', error, stackTrace);
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _musicPlayer?.stop();
    } catch (error, stackTrace) {
      _logPlaybackError('stopping background music', error, stackTrace);
    }
    try {
      await _ttsService?.stop();
    } catch (error, stackTrace) {
      _logPlaybackError('stopping narration', error, stackTrace);
    }
  }

  static void _logPlaybackError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('Error $operation: $error');
    debugPrint('$stackTrace');
  }

  Future<void> _recordAnalytics({required bool completed}) {
    final store = analyticsStore;
    final mode = analyticsMode;
    final startedAt = _analyticsStartedAt;
    if (store == null ||
        mode == null ||
        startedAt == null ||
        _analyticsRecorded) {
      return Future.value();
    }

    _analyticsRecorded = true;
    return store.recordSession(
      MeditationSessionRecord(
        mode: mode,
        startedAt: startedAt,
        endedAt: DateTime.now(),
        completed: completed,
      ),
    );
  }
}

class BiometricMeditation extends Meditation {
  final Measurement measurement;

  BiometricMeditation({
    required super.userAccount,
    super.maxSegments = BioAdaptiveModeConfig.meditationSegmentCount,
    super.meditationSegmentDuration,
    super.promptPolicy,
    super.analyticsStore,
    super.analyticsMode,
    super.diagnosticEventSink,
    required this.measurement,
  });

  /// One segment of lookahead, no more: the next request reports the
  /// biometrics read when the current segment begins, so producing further
  /// ahead would send readings from progressively further in the past.
  @override
  int get narrationPrefetchDepth => 1;

  @override
  bool checkEarlyExit() => measurement.hasHeartRateRecoveredToBaseline;

  @override
  HeartRateSample? readCurrentBiometrics() =>
      promptPolicy.includePhysiologicalInformation
          ? measurement.latestBiometrics
          : null;
}

class ScheduledMeditation extends Meditation {
  static const segmentCount = TimedModeConfig.segmentCount;

  final DateTime scheduledTime;

  ScheduledMeditation({
    required super.userAccount,
    required this.scheduledTime,
    required MeditationAnalyticsStore analyticsStore,
  }) : super(
          maxSegments: segmentCount,
          meditationSegmentDuration: TimedModeConfig.segmentDurationOverride,
          analyticsStore: analyticsStore,
          analyticsMode: MeditationAnalyticsMode.timed,
        );

  /// A delayed timer tick must not permanently miss a meditation just because
  /// it did not run during the exact scheduled minute.
  bool isDue([DateTime? now]) => isScheduledTimeDue(
        scheduledTime: scheduledTime,
        now: now ?? DateTime.now(),
      );

  static bool isScheduledTimeDue({
    required DateTime scheduledTime,
    required DateTime now,
  }) =>
      !now.isBefore(scheduledTime);
}
