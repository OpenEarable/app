import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorConfigurationProvider with ChangeNotifier {
  final SensorConfigurationManager _sensorConfigurationManager;
  late final StreamSubscription _sensorConfigStateSubscription;

  final Map<SensorConfiguration, SensorConfigurationValue> _sensorConfigurations = {};
  final Map<SensorConfiguration, Set<SensorConfigurationOption>> _sensorConfigurationOptions = {};

  SensorConfigurationProvider({required SensorConfigurationManager sensorConfigurationManager})
      : _sensorConfigurationManager = sensorConfigurationManager {
    _sensorConfigStateSubscription = _sensorConfigurationManager.sensorConfigurationStream.listen(_updatedValues);
  }

  void _updatedValues(Map<SensorConfiguration, SensorConfigurationValue> values) {
    for (var entry in values.entries) {
      final sensorConfiguration = entry.key;
      final sensorConfigurationValue = entry.value;

      _sensorConfigurations[sensorConfiguration] = sensorConfigurationValue;
      if (sensorConfigurationValue is ConfigurableSensorConfigurationValue) {
        for (SensorConfigurationOption option in sensorConfigurationValue.options) {
          if (!_sensorConfigurationOptions.containsKey(sensorConfiguration)) {
            _sensorConfigurationOptions[sensorConfiguration] = {};
          }
          _sensorConfigurationOptions[sensorConfiguration]!.add(option);
        }
        for (SensorConfigurationOption option in _sensorConfigurationOptions[sensorConfiguration] ?? {}) {
          if (!sensorConfigurationValue.options.contains(option)) {
            // Remove options that are no longer valid
            _sensorConfigurationOptions[sensorConfiguration]!.remove(option);
          }
        }
      }
    }
    notifyListeners();
  }

  void addSensorConfiguration(SensorConfiguration sensorConfiguration, SensorConfigurationValue sensorConfigurationValue) {
    _sensorConfigurations[sensorConfiguration] = sensorConfigurationValue;
    notifyListeners();
  }

  SensorConfigurationValue? getSelectedConfigurationValue(SensorConfiguration sensorConfiguration) {
    return _sensorConfigurations[sensorConfiguration];
  }

  List<(SensorConfiguration, SensorConfigurationValue)> getSelectedConfigurations() {
    return _sensorConfigurations.entries.map((entry) => (entry.key, entry.value)).toList();
  }

  Set<SensorConfigurationOption> getSelectedConfigurationOptions(SensorConfiguration sensorConfiguration) {
    return _sensorConfigurationOptions[sensorConfiguration] ?? {};
  }

  /// Adds a sensor configuration option to the given sensor configuration.
  /// 
  /// If the sensor configuration is a [ConfigurableSensorConfiguration], the selected value will be updated
  /// to the first possible value that matches the selected options.
  void addSensorConfigurationOption(SensorConfiguration sensorConfiguration, SensorConfigurationOption option) {
    if (_sensorConfigurationOptions[sensorConfiguration] == null) {
      _sensorConfigurationOptions[sensorConfiguration] = {};
    }
    _sensorConfigurationOptions[sensorConfiguration]?.add(option);
    _updateSelectedValue(sensorConfiguration);
    notifyListeners();
  }

  void _updateSelectedValue(SensorConfiguration<SensorConfigurationValue> sensorConfiguration) {
    List<SensorConfigurationValue> possibleValues = getSensorConfigurationValues(sensorConfiguration, distinct: true);
    SensorConfigurationValue? selectedValue = _sensorConfigurations[sensorConfiguration];

    if (selectedValue != null && possibleValues.contains(selectedValue)) {
      return; // Already valid and consistent
    }

    // Try to find a matching value based on options, even if not identical instance
    if (selectedValue is ConfigurableSensorConfigurationValue) {
      final SensorConfigurationValue? matchingValue = possibleValues.where(
        (value) =>
            value is ConfigurableSensorConfigurationValue &&
            value.withoutOptions() == selectedValue.withoutOptions(),
      ).firstOrNull;

      if (matchingValue != null) {
        // Direct assignment without recursive call
        _sensorConfigurations[sensorConfiguration] = matchingValue;
      } else {
        // Fall back to first available
        if (possibleValues.isNotEmpty) {
          _sensorConfigurations[sensorConfiguration] = possibleValues.last;
        }
      }
    } else {
      // Fall back to first available
      if (possibleValues.isNotEmpty) {
        _sensorConfigurations[sensorConfiguration] = possibleValues.last;
      }
    }
  }

  void removeSensorConfiguration(SensorConfiguration sensorConfiguration) {
    _sensorConfigurations.remove(sensorConfiguration);
    notifyListeners();
  }

  void removeSensorConfigurationOption(SensorConfiguration sensorConfiguration, SensorConfigurationOption option) {
    _sensorConfigurationOptions[sensorConfiguration]?.remove(option);
    _updateSelectedValue(sensorConfiguration);
    notifyListeners();
  }

  /// Returns a list of sensor configuration values for the given sensor configuration.
  /// If [distinct] is true, the values will be distinct based on their key and options.
  /// 
  /// If the sensor configuration is a [ConfigurableSensorConfiguration], the values will be filtered based on the selected options.
  List<SensorConfigurationValue> getSensorConfigurationValues(SensorConfiguration sensorConfiguration, {bool distinct=false}) {
    if (sensorConfiguration is ConfigurableSensorConfiguration) {
      List<SensorConfigurationValue> values = sensorConfiguration.values.where((value) {
        Set<SensorConfigurationOption> options = _sensorConfigurationOptions[sensorConfiguration] ?? {};
        if (distinct) {
          return setEquals(value.options, options);
        }
        return options.every((option) => value.options.contains(option));
      }).toList();

      return values;
    }

    if (distinct) {
      return sensorConfiguration.values.toSet().toList();
    }
    return sensorConfiguration.values;
  }

  @override
  void dispose() {
    _sensorConfigStateSubscription.cancel();
    super.dispose();
  }
}
