import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/labels/label_group.dart';

import 'label.dart';

/// A wearable that provides labeling functionality.
///
/// This is used as an Adapter for the RecorderProvider to record labels
/// alongside sensor data.
class LabelWearable extends Wearable implements SensorManager {
  LabelWearable({
    required this.labelGroup,
    required Stream<(int, List<Label>)> labelStream,
  })  : _labelStream = labelStream,
        super(
          name: "Label",
          disconnectNotifier: WearableDisconnectNotifier(),
        );

  final LabelGroup labelGroup;
  final Stream<(int, List<Label>)> _labelStream;

  @override
  List<Sensor> get sensors => [
        LabelSensor(
          labelGroup: labelGroup,
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
    required this.labelGroup,
    required Stream<(int, List<Label>)> labelStream,
  })  : _labelStream = labelStream,
        super(
          sensorName: labelGroup.name,
          chartTitle: "",
          shortChartTitle: "",
        );

  final LabelGroup labelGroup;
  final Stream<(int, List<Label>)> _labelStream;

  @override
  List<String> get axisNames =>
      labelGroup.labels.map((label) => label.name).toList()
        ..sort((a, b) => a.compareTo(b));

  @override
  List<String> get axisUnits =>
      labelGroup.labels.map((_) => "isActive").toList();

  @override
  Stream<SensorLabelValue> get sensorStream => _labelStream.map(
        (data) => SensorLabelValue(
          group: labelGroup,
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
    required LabelGroup group,
    required List<Label> selectedLabels,
    required super.timestamp,
  })  : labelStates = _buildLabelStates(group, selectedLabels),
        super(
          valueStrings: _buildValueStrings(group, selectedLabels),
        );

  /// Builds the sorted label -> active map.
  static Map<Label, bool> _buildLabelStates(
    LabelGroup group,
    List<Label> selectedLabels,
  ) {
    final sortedLabels = [...group.labels]
      ..sort((a, b) => a.name.compareTo(b.name));

    return {
      for (final label in sortedLabels) label: selectedLabels.contains(label),
    };
  }

  /// Builds the valueStrings in the same deterministic order.
  static List<String> _buildValueStrings(
    LabelGroup group,
    List<Label> selectedLabels,
  ) {
    final sortedLabels = [...group.labels]
      ..sort((a, b) => a.name.compareTo(b.name));

    return sortedLabels
        .map((label) => selectedLabels.contains(label).toString())
        .toList();
  }
}
