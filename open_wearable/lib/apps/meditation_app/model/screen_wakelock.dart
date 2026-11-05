import 'package:flutter/foundation.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the display awake for as long as the meditation in-app is open.
///
/// A meditation runs for minutes with no touch input while it waits on DeepSeek
/// and the text-to-speech service. When Android turns the screen off it
/// suspends those requests, so a session stalls partway through. This is not a
/// background-execution solution — it simply prevents the idle timeout while
/// the in-app is on screen.
///
/// The host app already exposes a global "keep app in foreground" setting that
/// drives the same wakelock, so releasing unconditionally on exit would silently
/// switch that setting off. [release] therefore restores whatever the host
/// setting asks for rather than assuming the lock should be dropped.
abstract final class ScreenWakelock {
  /// Whether this in-app currently holds the lock, so paired acquire/release
  /// calls from a widget lifecycle cannot get out of step.
  static bool _held = false;

  @visibleForTesting
  static bool get isHeld => _held;

  /// Overridable so tests can observe the calls without a platform channel.
  @visibleForTesting
  static Future<void> Function(bool enable) toggle =
      (enable) => WakelockPlus.toggle(enable: enable);

  /// Restores the default platform-backed implementation.
  @visibleForTesting
  static void resetForTesting() {
    toggle = (enable) => WakelockPlus.toggle(enable: enable);
    _held = false;
  }

  static Future<void> acquire() async {
    if (_held) return;
    _held = true;
    await _apply(true);
  }

  static Future<void> release() async {
    if (!_held) return;
    _held = false;
    // Hand the lock back to the host app's own setting instead of forcing it
    // off; the user may have asked for it globally.
    await _apply(AppShutdownSettings.keepAppInForeground);
  }

  static Future<void> _apply(bool enable) async {
    try {
      await toggle(enable);
    } catch (error) {
      // Keeping the screen on is a convenience. An unsupported platform or a
      // runtime failure must never stop a meditation from starting.
      debugPrint('Could not set the screen wakelock: $error');
    }
  }
}
