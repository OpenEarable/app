import 'package:open_earable/apps/driving_assistant/controller/tiredness_monitor.dart';

class SearchPattern {
  static bool tirednessCheck(double gyroY, TrackingSettings settings) {
    return gyroY >= settings.gyroYThreshold;
  }
}
