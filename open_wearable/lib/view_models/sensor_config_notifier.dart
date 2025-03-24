import 'package:flutter/widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorConfigNotifier with ChangeNotifier {
  // final Map<String, SensorConfiguration> _sensorConfigurations = {};
  final Map<SensorConfiguration, SensorConfigurationValue> _sensorConfigurationValues = {};

  // Map<String, SensorConfiguration> get sensorConfigurations => _sensorConfigurations;
  Map<SensorConfiguration, SensorConfigurationValue> get sensorConfigurationValues => _sensorConfigurationValues;

  void addSensorConfiguration(SensorConfiguration sensorConfiguration, SensorConfigurationValue sensorConfigurationValue) {
    // _sensorConfigurations[sensorConfiguration.name] = sensorConfiguration;
    _sensorConfigurationValues[sensorConfiguration] = sensorConfigurationValue;
    notifyListeners();
  }
}

class SensorConfigInheritedNotifier extends InheritedNotifier<SensorConfigNotifier> {
  const SensorConfigInheritedNotifier({
    super.key,
    required SensorConfigNotifier super.notifier,
    required super.child,
  });

  static SensorConfigNotifier of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<SensorConfigInheritedNotifier>();
    if (result == null) {
      throw FlutterError('SensorConfigInheritedNotifier.of() called with a context that does not contain a SensorConfigNotifier.');
    }
    if (result.notifier == null) {
      throw FlutterError('SensorConfigInheritedNotifier.of() called with a context that does not contain a SensorConfigNotifier.');
    }
    return result.notifier!;
  }
}