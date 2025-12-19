import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/labels/label_set.dart';

import 'label.dart';

/// A wearable that provides labeling functionality.
/// 
/// This is used as an Adapter for the RecorderProvider to record labels
/// alongside sensor data.
class LabelWearable extends Wearable implements SensorManager {
  LabelWearable({
    required this.labelSet,
    required Stream<(int, List<Label>)> labelStream,
  }) : _labelStream = labelStream,
       super(
         name: "Label",
         disconnectNotifier: WearableDisconnectNotifier(),
       );

  final LabelSet labelSet;
  final Stream<(int, List<Label>)> _labelStream;

  @override
  List<Sensor> get sensors => [
    LabelSensor(
      labelSet: labelSet,
      labelStream: _labelStream,
    ),
  ];
      
  @override
  String get deviceId => "label";

  @override
  Future<void> disconnect() {
    throw UnimplementedError();
  }
}

class LabelSensor extends Sensor<SensorLabelValue> {
  LabelSensor({
    required this.labelSet,
    required Stream<(int, List<Label>)> labelStream,
  }): _labelStream = labelStream,
      super(sensorName: "Label_${labelSet.name}", chartTitle: "", shortChartTitle: "");

  final LabelSet labelSet;
  final Stream<(int, List<Label>)> _labelStream;

  @override
  List<String> get axisNames => labelSet.labels
      .map((label) => label.name)
      .toList()
    ..sort((a, b) => a.compareTo(b));

  @override
  List<String> get axisUnits => labelSet.labels
      .map((_) => "isActive")
      .toList();

  @override
  Stream<SensorLabelValue> get sensorStream => _labelStream.map(
        (data) => SensorLabelValue(
          set: labelSet,
          selectedLabels: data.$2,
          timestamp: data.$1,
        ),
      );
}

class SensorLabelValue extends SensorValue {
  /// Maps each label to whether it is active.
  /// Labels are guaranteed to be sorted alphabetically by name.
  final Map<Label, bool> labelStates;

  SensorLabelValue({
    required LabelSet set,
    required List<Label> selectedLabels,
    required super.timestamp,
  })  : labelStates = _buildLabelStates(set, selectedLabels),
        super(
          valueStrings: _buildValueStrings(set, selectedLabels),
        );

  /// Builds the sorted label -> active map.
  static Map<Label, bool> _buildLabelStates(
    LabelSet set,
    List<Label> selectedLabels,
  ) {
    final sortedLabels = [...set.labels]
      ..sort((a, b) => a.name.compareTo(b.name));

    return {
      for (final label in sortedLabels)
        label: selectedLabels.contains(label),
    };
  }

  /// Builds the valueStrings in the same deterministic order.
  static List<String> _buildValueStrings(
    LabelSet set,
    List<Label> selectedLabels,
  ) {
    final sortedLabels = [...set.labels]
      ..sort((a, b) => a.name.compareTo(b.name));

    return sortedLabels
        .map((label) => selectedLabels.contains(label).toString())
        .toList();
  }
}
