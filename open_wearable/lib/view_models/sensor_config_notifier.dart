import 'package:flutter/widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorConfigNotifier with ChangeNotifier {
  final Map<SensorConfiguration, SensorConfigurationValue> _sensorConfigurationValues = {};
  Map<SensorConfiguration, SensorConfigurationValue> get sensorConfigurationValues => _sensorConfigurationValues;

  void addSensorConfiguration(SensorConfiguration sensorConfiguration, SensorConfigurationValue sensorConfigurationValue) {
    _sensorConfigurationValues[sensorConfiguration] = sensorConfigurationValue;
    notifyListeners();
  }
}
