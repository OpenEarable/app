import 'dart:collection';

final class DataPoint extends LinkedListEntry<DataPoint>{
  bool alerted;
  final double yaw;
  final double pitch;
  final double roll;
  final DataPoint previous;

  DataPoint(this.alerted, this.yaw, this.pitch, this.roll, this.previous);

  @override
  String toString() {
    return '$yaw : $pitch : $roll';
  }
}