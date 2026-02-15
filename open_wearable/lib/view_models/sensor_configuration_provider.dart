import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;

import '../models/logger.dart';

class SensorConfigurationRestoreResult {
  final int restoredCount;
  final int requestedCount;
  final int skippedCount;
  final int unknownConfigCount;

  const SensorConfigurationRestoreResult({
    required this.restoredCount,
    required this.requestedCount,
    required this.skippedCount,
    required this.unknownConfigCount,
  });

  bool get hasRestoredValues => restoredCount > 0;
}

class SensorConfigurationProvider with ChangeNotifier {
  final SensorConfigurationManager _sensorConfigurationManager;

  final Map<SensorConfiguration, SensorConfigurationValue>
      _sensorConfigurations = {};
  final Map<SensorConfiguration, Set<SensorConfigurationOption>>
      _sensorConfigurationOptions = {};
  final Set<SensorConfiguration> _pendingConfigurations = {};

  StreamSubscription<Map<SensorConfiguration, SensorConfigurationValue>>?
      _sensorConfigurationSubscription;

  SensorConfigurationProvider({
    required SensorConfigurationManager sensorConfigurationManager,
  }) : _sensorConfigurationManager = sensorConfigurationManager {
    _sensorConfigurationSubscription =
        _sensorConfigurationManager.sensorConfigurationStream.listen((event) {
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
    SensorConfigurationValue sensorConfigurationValue, {
    bool markPending = true,
  }) {
    _sensorConfigurations[sensorConfiguration] = sensorConfigurationValue;
    if (markPending) {
      _pendingConfigurations.add(sensorConfiguration);
    }
    notifyListeners();
  }

  SensorConfigurationValue? getSelectedConfigurationValue(
    SensorConfiguration sensorConfiguration,
  ) {
    return _sensorConfigurations[sensorConfiguration];
  }

  List<(SensorConfiguration, SensorConfigurationValue)>
      getSelectedConfigurations({
    bool pendingOnly = false,
  }) {
    return _sensorConfigurations.entries
        .where(
          (entry) => !pendingOnly || _pendingConfigurations.contains(entry.key),
        )
        .map((entry) => (entry.key, entry.value))
        .toList();
  }

  bool get hasPendingChanges => _pendingConfigurations.isNotEmpty;

  void clearPendingChanges({
    Iterable<SensorConfiguration>? onlyFor,
  }) {
    bool changed = false;
    if (onlyFor == null) {
      changed = _pendingConfigurations.isNotEmpty;
      _pendingConfigurations.clear();
    } else {
      for (final config in onlyFor) {
        changed = _pendingConfigurations.remove(config) || changed;
      }
    }
    if (changed) {
      notifyListeners();
    }
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
    SensorConfigurationOption option, {
    bool markPending = true,
  }) {
    if (_sensorConfigurationOptions[sensorConfiguration] == null) {
      _sensorConfigurationOptions[sensorConfiguration] = {};
    }
    _sensorConfigurationOptions[sensorConfiguration]?.add(option);
    _updateSelectedValue(
      sensorConfiguration,
      markPending: markPending,
    );
    if (markPending) {
      _pendingConfigurations.add(sensorConfiguration);
    }
    notifyListeners();
  }

  void _updateSelectedValue(
    SensorConfiguration<SensorConfigurationValue> sensorConfiguration, {
    bool markPending = true,
  }) {
    List<SensorConfigurationValue> possibleValues =
        getSensorConfigurationValues(sensorConfiguration, distinct: true);
    if (possibleValues.isEmpty) {
      return;
    }

    final selectedValue = _sensorConfigurations[sensorConfiguration];
    if (selectedValue == null) {
      _sensorConfigurations[sensorConfiguration] = possibleValues.first;
      if (markPending) {
        _pendingConfigurations.add(sensorConfiguration);
      }
      return;
    }
    if (possibleValues.contains(selectedValue)) {
      return;
    }

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

      _sensorConfigurations[sensorConfiguration] =
          matchingValue ?? possibleValues.last;
      if (markPending) {
        _pendingConfigurations.add(sensorConfiguration);
      }
      return;
    }

    logger.e(
      "Selected value is not a ConfigurableSensorConfigurationValue and we do not know how to handle it",
    );
    _sensorConfigurations[sensorConfiguration] = possibleValues.first;
    if (markPending) {
      _pendingConfigurations.add(sensorConfiguration);
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
        _sensorConfigurations[sensorConfiguration]
            as ConfigurableSensorConfigurationValue?;
    if (selectedValue == null) {
      _sensorConfigurationOptions[sensorConfiguration]!.clear();
      return;
    }
    _sensorConfigurationOptions[sensorConfiguration] =
        selectedValue.options.toSet();
  }

  void removeSensorConfiguration(SensorConfiguration sensorConfiguration) {
    _sensorConfigurations.remove(sensorConfiguration);
    _pendingConfigurations.remove(sensorConfiguration);
    notifyListeners();
  }

  void removeSensorConfigurationOption(
    SensorConfiguration sensorConfiguration,
    SensorConfigurationOption option, {
    bool markPending = true,
  }) {
    _sensorConfigurationOptions[sensorConfiguration]?.remove(option);
    _updateSelectedValue(
      sensorConfiguration,
      markPending: markPending,
    );
    if (markPending) {
      _pendingConfigurations.add(sensorConfiguration);
    }
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
        addSensorConfiguration(sensorConfiguration, value, markPending: true);
        _updateSelectedOptions(sensorConfiguration);
        sensorConfiguration.setConfiguration(value);
      }
      notifyListeners();
    }
  }

  Map<String, String> toJson() {
    return _sensorConfigurations.map(
      (config, value) => MapEntry(config.name, value.key),
    );
  }

  Future<SensorConfigurationRestoreResult> restoreFromJson(
    Map<String, String> jsonMap,
  ) async {
    final restoredConfigurations =
        <SensorConfiguration, SensorConfigurationValue>{};
    int requestedCount = 0;
    int skippedCount = 0;

    final knownConfigurations =
        _sensorConfigurationManager.sensorConfigurations.toList();
    final knownConfigNames =
        knownConfigurations.map((config) => config.name).toSet();

    for (final config in knownConfigurations) {
      final selectedKey = jsonMap[config.name];
      if (selectedKey == null) continue;

      requestedCount += 1;

      final matchingValue = config.values
          .where((value) => value.key == selectedKey)
          .cast<SensorConfigurationValue?>()
          .firstOrNull;

      if (matchingValue == null) {
        skippedCount += 1;
        logger.w(
          'Skipped restoring "${config.name}" because value "$selectedKey" is no longer available.',
        );
        continue;
      }

      restoredConfigurations[config] = matchingValue;
    }

    for (final config in restoredConfigurations.keys) {
      _sensorConfigurations[config] = restoredConfigurations[config]!;
      _updateSelectedOptions(config);
      _pendingConfigurations.add(config);
    }

    if (restoredConfigurations.isNotEmpty) {
      notifyListeners();
    }

    final unknownConfigCount =
        jsonMap.keys.where((name) => !knownConfigNames.contains(name)).length;

    return SensorConfigurationRestoreResult(
      restoredCount: restoredConfigurations.length,
      requestedCount: requestedCount,
      skippedCount: skippedCount,
      unknownConfigCount: unknownConfigCount,
    );
  }

  @override
  void dispose() {
    _sensorConfigurationSubscription?.cancel();
    super.dispose();
  }
}
