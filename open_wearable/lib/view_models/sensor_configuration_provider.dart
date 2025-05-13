import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorConfigurationProvider with ChangeNotifier {
  final Map<SensorConfiguration, SensorConfigurationValue> _sensorConfigurations = {};
  final Map<SensorConfiguration, List<SensorConfigurationOption>> _sensorConfigurationOptions = {};

  Map<SensorConfiguration, SensorConfigurationValue> get sensorConfigurations => _sensorConfigurations;

  Map<SensorConfiguration, List<SensorConfigurationOption>> get sensorConfigurationOptions => _sensorConfigurationOptions;

  void addSensorConfiguration(SensorConfiguration sensorConfiguration, SensorConfigurationValue sensorConfigurationValue) {
    _sensorConfigurations[sensorConfiguration] = sensorConfigurationValue;
    notifyListeners();
  }
}