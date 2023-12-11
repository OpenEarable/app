import 'dart:collection';

final class DataPoint extends LinkedListEntry<DataPoint>{
  bool alerted;
  final double yaw;
  final double pitch;
  final double roll;

  DataPoint(this.alerted, this.yaw, this.pitch, this.roll);

  @override
  String toString() {
    return '$yaw : $pitch : $roll';
  }
}