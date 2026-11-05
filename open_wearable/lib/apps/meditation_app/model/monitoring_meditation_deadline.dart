import 'dart:async';

import 'package:flutter/foundation.dart';

/// Ensures a demo can showcase its intervention within a bounded monitoring
/// period without changing the physiological stress detector itself.
class MonitoringMeditationDeadline {
  final Duration? delay;
  final VoidCallback onElapsed;

  final Stopwatch _elapsed = Stopwatch();
  Timer? _timer;
  bool _enteredMonitoring = false;
  bool _satisfied = false;
  bool _disposed = false;

  MonitoringMeditationDeadline({
    required this.delay,
    required this.onElapsed,
  });

  void reset() {
    _timer?.cancel();
    _elapsed
      ..stop()
      ..reset();
    _enteredMonitoring = false;
    _satisfied = false;
  }

  void enterMonitoring() {
    if (delay == null || _enteredMonitoring || _satisfied || _disposed) return;
    _enteredMonitoring = true;
    _elapsed.start();
    _schedule();
  }

  void pause() {
    _timer?.cancel();
    _elapsed.stop();
  }

  void resume() {
    if (delay == null || !_enteredMonitoring || _satisfied || _disposed) return;
    _elapsed.start();
    _schedule();
  }

  /// Any meditation started during monitoring satisfies the guarantee,
  /// regardless of whether stress detection or the deadline initiated it.
  void satisfy() {
    if (_satisfied) return;
    _satisfied = true;
    _timer?.cancel();
    _elapsed.stop();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _elapsed.stop();
  }

  void _schedule() {
    _timer?.cancel();
    final configuredDelay = delay;
    if (configuredDelay == null) return;
    final remaining = configuredDelay - _elapsed.elapsed;
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, _expire);
  }

  void _expire() {
    if (_disposed || _satisfied) return;
    _satisfied = true;
    _elapsed.stop();
    onElapsed();
  }
}
