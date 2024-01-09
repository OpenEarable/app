import '../utils/number-utils.dart';
import 'entity.dart';
import 'record_value.dart';

/// Defines a storable recording
class Recording extends Entity {
  Recording({
    String? id,
    required this.datetime,
    required this.yaw,
    required this.roll,
    required this.pitch,
  }) : super(id);

  final DateTime datetime;
  final RecordValue yaw;
  final RecordValue roll;
  final RecordValue pitch;

  /// Encodes the recording separating its fields by comma
  /// This can be considered as CSV-Format encoding
  /// Returns a [String]
  String encode() {
    return "$id,${datetime.year}-${leadingZeroToDigit(datetime.month)}-${leadingZeroToDigit(datetime.day)} ${leadingZeroToDigit(datetime.hour)}:${leadingZeroToDigit(datetime.minute)},${roll.min},${roll.max},${pitch.min},${pitch.max},${yaw.min},${yaw.max}";
  }

  /// Decodes a record encoded by [encoded]
  /// Returns a [Recording]
  static Recording decode(String encoded) {
    final parts = encoded.split(',');
    return Recording(
      id: parts[0],
      datetime: DateTime.parse('${parts[1]}:00'),
      roll: RecordValue(min: int.parse(parts[2]), max: int.parse(parts[3])),
      pitch: RecordValue(min: int.parse(parts[4]), max: int.parse(parts[5])),
      yaw: RecordValue(min: int.parse(parts[6]), max: int.parse(parts[7])),
    );
  }
}
