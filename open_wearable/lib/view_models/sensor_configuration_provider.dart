import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorConfigurationProvider with ChangeNotifier {
  final Map<SensorConfiguration, SensorConfigurationValue> _sensorConfigurations = {};

  Map<SensorConfiguration, SensorConfigurationValue> get sensorConfigurations => _sensorConfigurations;

  void addSensorConfiguration(SensorConfiguration sensorConfiguration, SensorConfigurationValue sensorConfigurationValue) {
    _sensorConfigurations[sensorConfiguration] = sensorConfigurationValue;
    notifyListeners();
  }
}