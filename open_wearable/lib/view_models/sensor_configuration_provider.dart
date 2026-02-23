import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;

import '../models/logger.dart';

/// Summary of a profile/configuration restore attempt.
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

/// Per-device sensor configuration state and reconciliation layer.
///
/// Needs:
/// - A `SensorConfigurationManager` from a connected wearable.
///
/// Does:
/// - Tracks selected values/options and pending edits.
/// - Reconciles optimistic local state with reported hardware state.
/// - Exposes apply/read helpers used by configuration UI and profile flows.
///
/// Provides:
/// - Query APIs for selected/applied/pending state.
/// - Mutation APIs for option/value changes and sensor shutdown.
class SensorConfigurationProvider with ChangeNotifier {
  final SensorConfigurationManager _sensorConfigurationManager;

  final Map<SensorConfiguration, SensorConfigurationValue>
      _sensorConfigurations = {};
  final Map<SensorConfiguration, Set<SensorConfigurationOption>>
      _sensorConfigurationOptions = {};
  final Set<SensorConfiguration> _pendingConfigurations = {};
  final Set<String> _lastReportedConfigurationKeys = {};
  final Map<String, SensorConfigurationValue> _lastReportedConfigurations = {};
  bool _hasReceivedConfigurationReport = false;

  StreamSubscription<Map<SensorConfiguration, SensorConfigurationValue>>?
      _sensorConfigurationSubscription;

  SensorConfigurationProvider({
    required SensorConfigurationManager sensorConfigurationManager,
  }) : _sensorConfigurationManager = sensorConfigurationManager {
    _sensorConfigurationSubscription =
        _sensorConfigurationManager.sensorConfigurationStream.listen((event) {
      _hasReceivedConfigurationReport = true;
      _lastReportedConfigurations
        ..clear()
        ..addEntries(
          event.entries.map(
            (entry) => MapEntry(
              _configurationIdentityKey(entry.key),
              entry.value,
            ),
          ),
        );
      _lastReportedConfigurationKeys
        ..clear()
        ..addAll(_lastReportedConfigurations.keys);

      var hasStateChange = false;
      for (final e in event.entries) {
        final sensorConfiguration = e.key;
        final sensorConfigurationValue = e.value;
        final currentValue = _sensorConfigurations[sensorConfiguration];
        final isPending = _pendingConfigurations.contains(sensorConfiguration);

        if (isPending) {
          // Keep optimistic local edits stable until the hardware reports the
          // same value; this avoids transient drift in the UI.
          if (currentValue != null &&
              _configurationValuesMatch(
                currentValue,
                sensorConfigurationValue,
              )) {
            hasStateChange =
                _pendingConfigurations.remove(sensorConfiguration) ||
                    hasStateChange;
          } else {
            continue;
          }
        }

        if (currentValue == null ||
            !_configurationValuesMatch(
              currentValue,
              sensorConfigurationValue,
            )) {
          _sensorConfigurations[sensorConfiguration] = sensorConfigurationValue;
          hasStateChange = true;
        }

        // Update the selected options for configurable sensor configurations
        _updateSelectedOptions(sensorConfiguration);
      }
      if (hasStateChange) {
        notifyListeners();
      }
    });
  }

  void addSensorConfiguration(
    SensorConfiguration sensorConfiguration,
    SensorConfigurationValue sensorConfigurationValue, {
    bool markPending = true,
  }) {
    _sensorConfigurations[sensorConfiguration] = sensorConfigurationValue;
    _updateSelectedOptions(sensorConfiguration);
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

  List<(SensorConfiguration, SensorConfigurationValue)>
      getConfigurationsMissingFromLastReport() {
    if (!_hasReceivedConfigurationReport) {
      return const <(SensorConfiguration, SensorConfigurationValue)>[];
    }

    final missing = <(SensorConfiguration, SensorConfigurationValue)>[];
    for (final config in _sensorConfigurationManager.sensorConfigurations) {
      final selected = _sensorConfigurations[config];
      if (selected == null) {
        continue;
      }
      if (_lastReportedConfigurationKeys.contains(
        _configurationIdentityKey(config),
      )) {
        continue;
      }
      missing.add((config, selected));
    }
    return missing;
  }

  bool get hasReceivedConfigurationReport => _hasReceivedConfigurationReport;

  SensorConfigurationValue? getLastReportedConfigurationValue(
    SensorConfiguration sensorConfiguration,
  ) {
    final key = _configurationIdentityKey(sensorConfiguration);
    return _lastReportedConfigurations[key];
  }

  bool selectedMatchesConfigurationValue(
    SensorConfiguration sensorConfiguration,
    SensorConfigurationValue expected,
  ) {
    final selected = _sensorConfigurations[sensorConfiguration];
    if (selected == null) {
      return false;
    }
    return _configurationValuesMatch(selected, expected);
  }

  bool isConfigurationApplied(SensorConfiguration sensorConfiguration) {
    if (_pendingConfigurations.contains(sensorConfiguration)) {
      return false;
    }
    if (!_hasReceivedConfigurationReport) {
      return false;
    }

    final selected = _sensorConfigurations[sensorConfiguration];
    if (selected == null) {
      return false;
    }

    final reported = getLastReportedConfigurationValue(sensorConfiguration);
    if (reported == null) {
      return false;
    }
    return _configurationValuesMatch(selected, reported);
  }

  String _configurationIdentityKey(SensorConfiguration configuration) {
    final dynamic configDynamic = configuration;
    try {
      final sensorId = configDynamic.sensorId;
      if (sensorId is int) {
        return 'sensor:$sensorId';
      }
    } catch (_) {
      // Fall through to structural key.
    }

    final valuesKey = configuration.values
        .map((value) => value.key)
        .toList(growable: false)
      ..sort();
    return '${configuration.runtimeType}:${configuration.name}:${valuesKey.join('|')}';
  }

  bool _configurationValuesMatch(
    SensorConfigurationValue current,
    SensorConfigurationValue expected,
  ) {
    if (current is SensorFrequencyConfigurationValue &&
        expected is SensorFrequencyConfigurationValue) {
      return current.frequencyHz == expected.frequencyHz &&
          setEquals(_optionNameSet(current), _optionNameSet(expected));
    }

    if (current is ConfigurableSensorConfigurationValue &&
        expected is ConfigurableSensorConfigurationValue) {
      return _normalizeName(current.withoutOptions().key) ==
              _normalizeName(expected.withoutOptions().key) &&
          setEquals(_optionNameSet(current), _optionNameSet(expected));
    }

    return _normalizeName(current.key) == _normalizeName(expected.key);
  }

  Set<String> _optionNameSet(SensorConfigurationValue value) {
    if (value is! ConfigurableSensorConfigurationValue) {
      return const <String>{};
    }
    return value.options.map((option) => _normalizeName(option.name)).toSet();
  }

  String _normalizeName(String value) => value.trim().toLowerCase();

  bool get hasPendingChanges => _pendingConfigurations.isNotEmpty;

  bool isConfigurationPending(SensorConfiguration configuration) {
    return _pendingConfigurations.contains(configuration);
  }

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
    final shouldMarkPendingByConfiguration = <SensorConfiguration, bool>{};
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
      final selected = _sensorConfigurations[config];
      shouldMarkPendingByConfiguration[config] = selected == null ||
          !_configurationValuesMatch(selected, matchingValue);
    }

    var hasStateChange = false;
    for (final entry in restoredConfigurations.entries) {
      final config = entry.key;
      final value = entry.value;
      final selected = _sensorConfigurations[config];
      final selectedChanged =
          selected == null || !_configurationValuesMatch(selected, value);
      if (selectedChanged) {
        hasStateChange = true;
      }

      _sensorConfigurations[config] = value;
      _updateSelectedOptions(config);
      final shouldMarkPending =
          shouldMarkPendingByConfiguration[config] ?? true;
      if (shouldMarkPending) {
        hasStateChange = _pendingConfigurations.add(config) || hasStateChange;
        continue;
      }

      final reported = getLastReportedConfigurationValue(config);
      if (reported != null && _configurationValuesMatch(reported, value)) {
        hasStateChange =
            _pendingConfigurations.remove(config) || hasStateChange;
      }
    }

    if (restoredConfigurations.isNotEmpty && hasStateChange) {
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
