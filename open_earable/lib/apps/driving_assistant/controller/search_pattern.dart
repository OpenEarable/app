import 'package:open_earable/apps/driving_assistant/controller/data_point.dart';
import 'package:open_earable/apps/driving_assistant/controller/tiredness_monitor.dart';

class SearchPattern{
  static bool tirednessCheck(double gyroY, TrackingSettings settings){
    //TODO: Kann ich auf Beschleunigungsdaten zugreifen?
    /*
    if(point.previous != null && point.previous?.previous != null && point.next != null) {
      return
          point.previous!.pitch > point.pitch
          && point.previous!.previous!.pitch > point.previous!.pitch
          && point.next!.pitch > point.pitch
          && (point.next!.pitch - point.pitch) > 2 * (point.previous!.pitch - point.pitch);
    }
     */
    //return false;
    return gyroY >= settings.gyroYThreshold;
  }
}