/// Tracks whether an in-app feature flow is currently open.
///
/// This is used by lifecycle logic to decide whether temporary flow screens
/// should be closed after background-triggered sensor shutdown.
class AppLaunchSession {
  static int _openAppFlowCount = 0;

  static bool get hasOpenAppFlow => _openAppFlowCount > 0;

  static void markAppFlowOpened() {
    _openAppFlowCount += 1;
  }

  static void markAppFlowClosed() {
    if (_openAppFlowCount <= 0) {
      _openAppFlowCount = 0;
      return;
    }
    _openAppFlowCount -= 1;
  }

  static void reset() {
    _openAppFlowCount = 0;
  }
}
