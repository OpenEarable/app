import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_account.dart';

/// Persists the meditation app's profile, delivery preferences, and explicit
/// cloud-processing choice. API credentials remain in the dedicated service
/// settings store and its platform-secure storage.
class MeditationUserSettingsStore {
  static const _prefix = 'meditation.user_settings.';
  static const _initializedKey = '${_prefix}initialized';
  static const _firstNameKey = '${_prefix}first_name';
  static const _genderKey = '${_prefix}gender';
  static const _ageKey = '${_prefix}age';
  static const _fitnessLevelKey = '${_prefix}fitness_level';
  static const _speakingSpeedKey = '${_prefix}speaking_speed';
  static const _meditationTypeKey = '${_prefix}meditation_type';
  static const _meditationEnvironmentKey = '${_prefix}meditation_environment';
  static const _additionalPreferencesKey = '${_prefix}additional_preferences';
  static const _stressThresholdKey = '${_prefix}stress_threshold';
  static const _cloudProcessingConsentKey =
      '${_prefix}cloud_processing_consent';

  static const _allKeys = <String>[
    _initializedKey,
    _firstNameKey,
    _genderKey,
    _ageKey,
    _fitnessLevelKey,
    _speakingSpeedKey,
    _meditationTypeKey,
    _meditationEnvironmentKey,
    _additionalPreferencesKey,
    _stressThresholdKey,
    _cloudProcessingConsentKey,
  ];

  final Future<SharedPreferences> Function() _preferencesProvider;

  MeditationUserSettingsStore({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance;

  /// Restores values only after this store has completed at least one save.
  /// This avoids turning UI defaults into a silently accepted user profile.
  Future<bool> loadInto(UserAccount account) async {
    try {
      final preferences = await _preferencesProvider();
      if (!(preferences.getBool(_initializedKey) ?? false)) return false;

      account.firstName = _normalized(preferences.getString(_firstNameKey));
      account.gender = _enumOrNull(
        Gender.values,
        preferences.getString(_genderKey),
      );
      account.age = preferences.getInt(_ageKey);
      account.fitnessLevel = _enumOrNull(
        FitnessLevel.values,
        preferences.getString(_fitnessLevelKey),
      );
      account.speakingSpeed = _enumOrNull(
        SpeakingSpeed.values,
        preferences.getString(_speakingSpeedKey),
      );
      account.meditationType = _enumOrNull(
        MeditationType.values,
        preferences.getString(_meditationTypeKey),
      );
      account.meditationEnvironment = _enumOrNull(
        MeditationEnvironment.values,
        preferences.getString(_meditationEnvironmentKey),
      );
      account.additionalPreferences =
          _normalized(preferences.getString(_additionalPreferencesKey));
      account.stressThreshold = preferences.getDouble(_stressThresholdKey);
      account.cloudProcessingConsent =
          preferences.getBool(_cloudProcessingConsentKey);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Could not load meditation user settings: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  Future<void> save(UserAccount account) async {
    final preferences = await _preferencesProvider();
    await _writeString(preferences, _firstNameKey, account.firstName);
    await _writeEnum(preferences, _genderKey, account.gender);
    await _writeInt(preferences, _ageKey, account.age);
    await _writeEnum(preferences, _fitnessLevelKey, account.fitnessLevel);
    await _writeEnum(preferences, _speakingSpeedKey, account.speakingSpeed);
    await _writeEnum(preferences, _meditationTypeKey, account.meditationType);
    await _writeEnum(
      preferences,
      _meditationEnvironmentKey,
      account.meditationEnvironment,
    );
    await _writeString(
      preferences,
      _additionalPreferencesKey,
      account.additionalPreferences,
    );
    await _writeDouble(
      preferences,
      _stressThresholdKey,
      account.stressThreshold,
    );
    await _writeBool(
      preferences,
      _cloudProcessingConsentKey,
      account.cloudProcessingConsent,
    );
    // Written last so a partial first save is never restored as a profile.
    await preferences.setBool(_initializedKey, true);
  }

  /// Deletes only meditation profile/preferences. Service credentials and
  /// analytics are cleared by their owning stores from the in-app reset flow.
  Future<void> clear() async {
    final preferences = await _preferencesProvider();
    for (final key in _allKeys) {
      await preferences.remove(key);
    }
  }

  static void clearAccount(UserAccount account) {
    account
      ..firstName = null
      ..gender = null
      ..age = null
      ..fitnessLevel = null
      ..voiceGender = null
      ..speakingSpeed = null
      ..meditationType = null
      ..meditationEnvironment = null
      ..additionalPreferences = null
      ..stressThreshold = null
      ..baselineHeartRate = null
      ..baselineRMSSD = null
      ..cloudProcessingConsent = null;
  }

  static Future<void> _writeString(
    SharedPreferences preferences,
    String key,
    String? value,
  ) async {
    final normalized = _normalized(value);
    if (normalized == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, normalized);
    }
  }

  static Future<void> _writeEnum(
    SharedPreferences preferences,
    String key,
    Enum? value,
  ) async {
    if (value == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value.name);
    }
  }

  static Future<void> _writeInt(
    SharedPreferences preferences,
    String key,
    int? value,
  ) async {
    if (value == null) {
      await preferences.remove(key);
    } else {
      await preferences.setInt(key, value);
    }
  }

  static Future<void> _writeDouble(
    SharedPreferences preferences,
    String key,
    double? value,
  ) async {
    if (value == null) {
      await preferences.remove(key);
    } else {
      await preferences.setDouble(key, value);
    }
  }

  static Future<void> _writeBool(
    SharedPreferences preferences,
    String key,
    bool? value,
  ) async {
    if (value == null) {
      await preferences.remove(key);
    } else {
      await preferences.setBool(key, value);
    }
  }

  static String? _normalized(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static T? _enumOrNull<T extends Enum>(Iterable<T> values, String? name) {
    if (name == null) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
