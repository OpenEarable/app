import 'package:flutter/foundation.dart' show setEquals;
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

enum ProfileApplicationState {
  none,
  selected,
  applied,
  mixed,
}

enum DeviceProfileConfigState {
  notSelected,
  selected,
  applied,
  unavailable,
}

class DeviceConfigSnapshot {
  final DeviceProfileConfigState state;
  final SensorConfigurationValue? selectedValue;

  const DeviceConfigSnapshot({
    required this.state,
    required this.selectedValue,
  });
}

class ResolvedProfileValue {
  final String samplingLabel;
  final List<SensorConfigurationOption> dataTargetOptions;

  const ResolvedProfileValue({
    required this.samplingLabel,
    required this.dataTargetOptions,
  });
}

class SensorProfileService {
  const SensorProfileService._();

  static ProfileApplicationState resolveProfileApplicationState({
    required Wearable primaryDevice,
    required SensorConfigurationProvider primaryProvider,
    required SensorConfigurationProvider? pairedProvider,
    required Wearable? pairedDevice,
    required Map<String, String>? profileConfig,
  }) {
    if (profileConfig == null || profileConfig.isEmpty) {
      return ProfileApplicationState.none;
    }

    final primaryState = resolveSingleDeviceProfileState(
      device: primaryDevice,
      provider: primaryProvider,
      expectedConfig: profileConfig,
    );

    if (pairedDevice == null || pairedProvider == null) {
      return primaryState;
    }

    final mirroredProfile = buildMirroredProfileConfig(
      sourceDevice: primaryDevice,
      targetDevice: pairedDevice,
      sourceProfileConfig: profileConfig,
    );
    if (mirroredProfile == null || mirroredProfile.isEmpty) {
      return ProfileApplicationState.mixed;
    }

    final secondaryState = resolveSingleDeviceProfileState(
      device: pairedDevice,
      provider: pairedProvider,
      expectedConfig: mirroredProfile,
    );

    if (primaryState == ProfileApplicationState.none &&
        secondaryState == ProfileApplicationState.none) {
      return ProfileApplicationState.none;
    }
    if (primaryState == secondaryState) {
      return primaryState;
    }
    return ProfileApplicationState.mixed;
  }

  static ProfileApplicationState resolveSingleDeviceProfileState({
    required Wearable device,
    required SensorConfigurationProvider provider,
    required Map<String, String> expectedConfig,
  }) {
    if (!device.hasCapability<SensorConfigurationManager>()) {
      return ProfileApplicationState.none;
    }

    final manager = device.requireCapability<SensorConfigurationManager>();
    var allSelected = true;
    var allApplied = provider.hasReceivedConfigurationReport;
    for (final entry in expectedConfig.entries) {
      final config = findConfigurationByName(
        manager: manager,
        configName: entry.key,
      );
      if (config == null) {
        return ProfileApplicationState.none;
      }

      final expectedValue = findConfigurationValueByKey(
        config: config,
        valueKey: entry.value,
      );
      if (expectedValue == null) {
        return ProfileApplicationState.none;
      }

      if (!provider.selectedMatchesConfigurationValue(config, expectedValue)) {
        allSelected = false;
      }

      if (allApplied) {
        final reportedValue =
            provider.getLastReportedConfigurationValue(config);
        if (reportedValue == null ||
            !configurationValuesMatch(reportedValue, expectedValue)) {
          allApplied = false;
        }
      } else {
        allApplied = false;
      }
    }

    if (allApplied) {
      return ProfileApplicationState.applied;
    }
    if (allSelected) {
      return ProfileApplicationState.selected;
    }
    return ProfileApplicationState.none;
  }

  static Map<String, String>? buildMirroredProfileConfig({
    required Wearable sourceDevice,
    required Wearable targetDevice,
    required Map<String, String> sourceProfileConfig,
  }) {
    if (!sourceDevice.hasCapability<SensorConfigurationManager>() ||
        !targetDevice.hasCapability<SensorConfigurationManager>()) {
      return null;
    }

    final sourceManager =
        sourceDevice.requireCapability<SensorConfigurationManager>();
    final targetManager =
        targetDevice.requireCapability<SensorConfigurationManager>();
    final mirrored = <String, String>{};

    for (final entry in sourceProfileConfig.entries) {
      final sourceConfig = findConfigurationByName(
        manager: sourceManager,
        configName: entry.key,
      );
      if (sourceConfig == null) {
        continue;
      }
      final sourceValue = findConfigurationValueByKey(
        config: sourceConfig,
        valueKey: entry.value,
      );
      if (sourceValue == null) {
        continue;
      }

      final mirroredConfig = findMirroredConfiguration(
        manager: targetManager,
        sourceConfig: sourceConfig,
      );
      if (mirroredConfig == null) {
        continue;
      }
      final mirroredValue = findMirroredValue(
        mirroredConfig: mirroredConfig,
        sourceValue: sourceValue,
      );
      if (mirroredValue == null) {
        continue;
      }
      mirrored[mirroredConfig.name] = mirroredValue.key;
    }

    return mirrored;
  }

  static DeviceConfigSnapshot buildDeviceConfigSnapshot({
    required SensorConfigurationProvider provider,
    required SensorConfiguration config,
    required SensorConfigurationValue expectedValue,
  }) {
    final selectedValue = provider.getSelectedConfigurationValue(config);
    if (selectedValue == null) {
      return const DeviceConfigSnapshot(
        state: DeviceProfileConfigState.notSelected,
        selectedValue: null,
      );
    }

    if (!provider.selectedMatchesConfigurationValue(config, expectedValue)) {
      return DeviceConfigSnapshot(
        state: DeviceProfileConfigState.notSelected,
        selectedValue: selectedValue,
      );
    }

    if (provider.isConfigurationApplied(config)) {
      return DeviceConfigSnapshot(
        state: DeviceProfileConfigState.applied,
        selectedValue: selectedValue,
      );
    }

    return DeviceConfigSnapshot(
      state: DeviceProfileConfigState.selected,
      selectedValue: selectedValue,
    );
  }

  static ResolvedProfileValue describeSensorConfigurationValue(
    SensorConfigurationValue value,
  ) {
    final baseValue = value is SensorFrequencyConfigurationValue
        ? formatFrequency(value.frequencyHz)
        : value.key;

    if (value is! ConfigurableSensorConfigurationValue) {
      return ResolvedProfileValue(
        samplingLabel: baseValue,
        dataTargetOptions: const [],
      );
    }

    final dataTargets = value.options
        .where(_isDataTargetOption)
        .toSet()
        .toList(growable: false)
      ..sort((a, b) => normalizeName(a.name).compareTo(normalizeName(b.name)));

    return ResolvedProfileValue(
      samplingLabel: dataTargets.isEmpty ? 'Off' : baseValue,
      dataTargetOptions: dataTargets,
    );
  }

  static String formatFrequency(double hz) {
    if ((hz - hz.roundToDouble()).abs() < 0.01) {
      return '${hz.round()} Hz';
    }
    if (hz >= 10) {
      return '${hz.toStringAsFixed(1)} Hz';
    }
    return '${hz.toStringAsFixed(2)} Hz';
  }

  static SensorConfiguration? findConfigurationByName({
    required SensorConfigurationManager manager,
    required String configName,
  }) {
    for (final config in manager.sensorConfigurations) {
      if (config.name == configName) {
        return config;
      }
    }

    final normalized = normalizeName(configName);
    for (final config in manager.sensorConfigurations) {
      if (normalizeName(config.name) == normalized) {
        return config;
      }
    }
    return null;
  }

  static SensorConfigurationValue? findConfigurationValueByKey({
    required SensorConfiguration config,
    required String valueKey,
  }) {
    for (final value in config.values) {
      if (value.key == valueKey) {
        return value;
      }
    }

    final normalized = normalizeName(valueKey);
    for (final value in config.values) {
      if (normalizeName(value.key) == normalized) {
        return value;
      }
    }
    return null;
  }

  static SensorConfiguration? findMirroredConfiguration({
    required SensorConfigurationManager manager,
    required SensorConfiguration sourceConfig,
  }) {
    for (final candidate in manager.sensorConfigurations) {
      if (candidate.name == sourceConfig.name) {
        return candidate;
      }
    }

    final normalizedSource = normalizeName(sourceConfig.name);
    for (final candidate in manager.sensorConfigurations) {
      if (normalizeName(candidate.name) == normalizedSource) {
        return candidate;
      }
    }
    return null;
  }

  static SensorConfigurationValue? findMirroredValue({
    required SensorConfiguration mirroredConfig,
    required SensorConfigurationValue sourceValue,
  }) {
    for (final candidate in mirroredConfig.values) {
      if (normalizeName(candidate.key) == normalizeName(sourceValue.key)) {
        return candidate;
      }
    }

    if (sourceValue is SensorFrequencyConfigurationValue) {
      final sourceOptions = optionNameSet(sourceValue);
      final candidates = mirroredConfig.values
          .whereType<SensorFrequencyConfigurationValue>()
          .toList(growable: false);
      if (candidates.isNotEmpty) {
        final sameOptionCandidates = candidates
            .where(
              (candidate) => setEquals(optionNameSet(candidate), sourceOptions),
            )
            .toList(growable: false);
        final scoped =
            sameOptionCandidates.isNotEmpty ? sameOptionCandidates : candidates;
        SensorFrequencyConfigurationValue? best;
        double? bestDistance;
        for (final candidate in scoped) {
          final distance =
              (candidate.frequencyHz - sourceValue.frequencyHz).abs();
          if (best == null || distance < bestDistance!) {
            best = candidate;
            bestDistance = distance;
          }
        }
        if (best != null) {
          return best;
        }
      }
    }

    if (sourceValue is ConfigurableSensorConfigurationValue) {
      final sourceWithoutOptions = sourceValue.withoutOptions();
      final sourceOptions = optionNameSet(sourceValue);
      for (final candidate in mirroredConfig.values
          .whereType<ConfigurableSensorConfigurationValue>()) {
        if (!setEquals(optionNameSet(candidate), sourceOptions)) {
          continue;
        }
        if (normalizeName(candidate.withoutOptions().key) ==
            normalizeName(sourceWithoutOptions.key)) {
          return candidate;
        }
      }
    }

    return null;
  }

  static bool configurationValuesMatchNullable(
    SensorConfigurationValue? left,
    SensorConfigurationValue? right,
  ) {
    if (left == null || right == null) {
      return left == null && right == null;
    }
    return configurationValuesMatch(left, right);
  }

  static bool configurationValuesMatch(
    SensorConfigurationValue left,
    SensorConfigurationValue right,
  ) {
    if (left is SensorFrequencyConfigurationValue &&
        right is SensorFrequencyConfigurationValue) {
      return left.frequencyHz == right.frequencyHz &&
          setEquals(optionNameSet(left), optionNameSet(right));
    }

    if (left is ConfigurableSensorConfigurationValue &&
        right is ConfigurableSensorConfigurationValue) {
      return normalizeName(left.withoutOptions().key) ==
              normalizeName(right.withoutOptions().key) &&
          setEquals(optionNameSet(left), optionNameSet(right));
    }

    return normalizeName(left.key) == normalizeName(right.key);
  }

  static Set<String> optionNameSet(SensorConfigurationValue value) {
    if (value is! ConfigurableSensorConfigurationValue) {
      return const <String>{};
    }
    return value.options.map((option) => normalizeName(option.name)).toSet();
  }

  static String normalizeName(String value) => value.trim().toLowerCase();

  static bool _isDataTargetOption(SensorConfigurationOption option) {
    return option is StreamSensorConfigOption ||
        option is RecordSensorConfigOption;
  }
}
