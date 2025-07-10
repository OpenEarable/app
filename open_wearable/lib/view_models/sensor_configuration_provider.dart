import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorConfigurationProvider with ChangeNotifier {
  final SensorConfigurationManager _sensorConfigurationManager;

  final Map<SensorConfiguration, SensorConfigurationValue>
      _sensorConfigurations = {};
  final Map<SensorConfiguration, Set<SensorConfigurationOption>>
      _sensorConfigurationOptions = {};

  StreamSubscription<Map<SensorConfiguration, SensorConfigurationValue>>?
      _sensorConfigurationSubscription;
  
  SensorConfigurationProvider({
    required SensorConfigurationManager sensorConfigurationManager,
  }) : _sensorConfigurationManager = sensorConfigurationManager {
    _sensorConfigurationSubscription = _sensorConfigurationManager.sensorConfigurationStream.listen((event) {
      for (final e in event.entries) {
        final sensorConfiguration = e.key;
        final sensorConfigurationValue = e.value;

        // Update the selected configuration value
        _sensorConfigurations[sensorConfiguration] = sensorConfigurationValue;

        // Update the selected options for configurable sensor configurations
        _updateSelectedOptions(sensorConfiguration);
      }
      notifyListeners();
    });
  }

  void addSensorConfiguration(
    SensorConfiguration sensorConfiguration,
    SensorConfigurationValue sensorConfigurationValue,
  ) {
    _sensorConfigurations[sensorConfiguration] = sensorConfigurationValue;
    notifyListeners();
  }

  SensorConfigurationValue? getSelectedConfigurationValue(
    SensorConfiguration sensorConfiguration,
  ) {
    return _sensorConfigurations[sensorConfiguration];
  }

  List<(SensorConfiguration, SensorConfigurationValue)>
      getSelectedConfigurations() {
    return _sensorConfigurations.entries
        .map((entry) => (entry.key, entry.value))
        .toList();
  }

  Set<SensorConfigurationOption> getSelectedConfigurationOptions(
    SensorConfiguration sensorConfiguration,
  ) {
    return _sensorConfigurationOptions[sensorConfiguration] ?? {};
  }

  /// Adds a sensor configuration option to the given sensor configuration.
  ///
  /// If the sensor configuration is a [ConfigurableSensorConfiguration], the selected value will be updated
  /// to the first possible value that matches the selected options.
  void addSensorConfigurationOption(
    SensorConfiguration sensorConfiguration,
    SensorConfigurationOption option,
  ) {
    if (_sensorConfigurationOptions[sensorConfiguration] == null) {
      _sensorConfigurationOptions[sensorConfiguration] = {};
    }
    _sensorConfigurationOptions[sensorConfiguration]?.add(option);
    _updateSelectedValue(sensorConfiguration);
    notifyListeners();
  }

  void _updateSelectedValue(
    SensorConfiguration<SensorConfigurationValue> sensorConfiguration,
  ) {
    List<SensorConfigurationValue> possibleValues =
        getSensorConfigurationValues(sensorConfiguration, distinct: true);
    SensorConfigurationValue? selectedValue =
        _sensorConfigurations[sensorConfiguration];
    if (selectedValue == null) {
      _sensorConfigurations[sensorConfiguration] = possibleValues.first;
    }
    if (!possibleValues.contains(selectedValue)) {
      if (selectedValue is ConfigurableSensorConfigurationValue) {
        final SensorConfigurationValue? matchingValue =
            getSensorConfigurationValues(sensorConfiguration)
                .where((value) {
                  if (value is ConfigurableSensorConfigurationValue) {
                    return value.withoutOptions() ==
                        selectedValue.withoutOptions();
                  }
                  return value == selectedValue;
                })
                .cast<SensorConfigurationValue?>()
                .toList()
                .firstOrNull;

        if (matchingValue == null) {
          logger.w(
            "No matching value found for ${sensorConfiguration.name} with options ${_sensorConfigurationOptions[sensorConfiguration]}",
          );
        }

        addSensorConfiguration(
          sensorConfiguration,
          matchingValue ?? possibleValues.last,
        );
      } else {
        logger.e(
          "Selected value is not a ConfigurableSensorConfigurationValue and we do not know how to handle it",
        );
      }
    }
  }

  void _updateSelectedOptions(SensorConfiguration sensorConfiguration) {
    if (_sensorConfigurationOptions[sensorConfiguration] == null) {
      _sensorConfigurationOptions[sensorConfiguration] = {};
    }
    if (sensorConfiguration is! ConfigurableSensorConfiguration) {
      _sensorConfigurationOptions[sensorConfiguration]!.clear();
      return;
    }
    ConfigurableSensorConfigurationValue? selectedValue =
        _sensorConfigurations[sensorConfiguration] as ConfigurableSensorConfigurationValue?;
    if (selectedValue == null) {
      _sensorConfigurationOptions[sensorConfiguration]!.clear();
      return;
    }
    _sensorConfigurationOptions[sensorConfiguration] = selectedValue.options.toSet();
  }

  void removeSensorConfiguration(SensorConfiguration sensorConfiguration) {
    _sensorConfigurations.remove(sensorConfiguration);
    notifyListeners();
  }

  void removeSensorConfigurationOption(
    SensorConfiguration sensorConfiguration,
    SensorConfigurationOption option,
  ) {
    _sensorConfigurationOptions[sensorConfiguration]?.remove(option);
    _updateSelectedValue(sensorConfiguration);
    notifyListeners();
  }

  /// Returns a list of sensor configuration values for the given sensor configuration.
  /// If [distinct] is true, the values will be distinct based on their key and options.
  ///
  /// If the sensor configuration is a [ConfigurableSensorConfiguration], the values will be filtered based on the selected options.
  List<SensorConfigurationValue> getSensorConfigurationValues(
    SensorConfiguration sensorConfiguration, {
    bool distinct = false,
  }) {
    if (sensorConfiguration is ConfigurableSensorConfiguration) {
      List<SensorConfigurationValue> values =
          sensorConfiguration.values.where((value) {
        Set<SensorConfigurationOption> options =
            _sensorConfigurationOptions[sensorConfiguration] ?? {};
        if (distinct) {
          return setEquals(value.options.toSet(), options);
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

  /// Turn off all sensors that have a off configuration value.
  Future<void> turnOffAllSensors() async {
    for (final sensorConfiguration in _sensorConfigurations.keys) {
      final SensorConfigurationValue? value = sensorConfiguration.offValue;
      if (value != null) {
        addSensorConfiguration(sensorConfiguration, value);
        _updateSelectedOptions(sensorConfiguration);
        notifyListeners();
      }
    }
  }

  Map<String, String> toJson() {
    return _sensorConfigurations.map((config, value) =>
        MapEntry(config.name, value.key),);
  }

  Future<bool> restoreFromJson(Map<String, String> jsonMap) async {
    Map<SensorConfiguration, SensorConfigurationValue>
        restoredConfigurations = {};
    for (final config in _sensorConfigurations.keys) {
      final selectedKey = jsonMap[config.name];
      if (selectedKey == null) continue;

      try {
        final SensorConfigurationValue matchingValue = config.values.firstWhere(
          (v) => v.key == selectedKey,
        );
        restoredConfigurations[config] = matchingValue;
      } on StateError {
        logger.e("Failed to restore configuration for ${config.name}");
        return false;
      }
    }
    for (final config in restoredConfigurations.keys) {
      _sensorConfigurations[config] = restoredConfigurations[config]!;
      _updateSelectedOptions(config);
    }
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _sensorConfigurationSubscription?.cancel();
    super.dispose();
  }
}
