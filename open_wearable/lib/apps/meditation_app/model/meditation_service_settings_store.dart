import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_account.dart';

/// Minimal interface around platform-secure storage so persistence can be
/// tested without invoking a method channel.
abstract interface class MeditationSecretStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class PlatformMeditationSecretStorage implements MeditationSecretStorage {
  static const _androidStorageNamespace = 'meditation_service_credentials';

  final FlutterSecureStorage _storage;

  PlatformMeditationSecretStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                storageNamespace: _androidStorageNamespace,
              ),
              // EarStreAM does not share credentials with another macOS app.
              // The standard Keychain remains OS-protected and avoids adding
              // a Keychain Sharing capability to OpenWearables' signing
              // profile solely for this in-app.
              mOptions: MacOsOptions(
                usesDataProtectionKeychain: false,
              ),
            );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Persists the service configuration edited on the API Keys page.
///
/// Provider and voice choices are ordinary preferences. Credentials are kept
/// in the OS-protected key store/keychain rather than SharedPreferences. The
/// A fresh public installation starts without credentials. After the first
/// save, this device's stored configuration takes precedence, including
/// intentionally cleared credentials.
class MeditationServiceSettingsStore {
  static const _prefix = 'meditation.service_settings.';
  static const _initializedKey = '${_prefix}initialized';
  static const _ttsProviderKey = '${_prefix}tts_provider';
  static const _voiceGenderKey = '${_prefix}voice_gender';
  static const _elevenLabsVoiceIdKey = '${_prefix}elevenlabs_voice_id';
  static const _tencentRegionKey = '${_prefix}tencent_region';
  static const _deepseekValidKey = '${_prefix}deepseek_valid';
  static const _elevenLabsValidKey = '${_prefix}elevenlabs_valid';
  static const _tencentValidKey = '${_prefix}tencent_valid';

  static const _deepseekApiKey = '${_prefix}deepseek_api_key';
  static const _elevenLabsApiKey = '${_prefix}elevenlabs_api_key';
  static const _tencentSecretIdKey = '${_prefix}tencent_secret_id';
  static const _tencentSecretKey = '${_prefix}tencent_secret_key';

  final Future<SharedPreferences> Function() _preferencesProvider;
  final MeditationSecretStorage _secretStorage;

  _ServiceSettingsSnapshot? _pendingSnapshot;
  Future<void>? _saveLoop;

  MeditationServiceSettingsStore({
    Future<SharedPreferences> Function()? preferencesProvider,
    MeditationSecretStorage? secretStorage,
  })  : _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance,
        _secretStorage = secretStorage ?? PlatformMeditationSecretStorage();

  /// Applies saved settings to [account]. Returns false when this device has
  /// never saved them or when storage could not be read.
  Future<bool> loadInto(UserAccount account) async {
    try {
      final preferences = await _preferencesProvider();
      if (!(preferences.getBool(_initializedKey) ?? false)) return false;

      final secrets = await Future.wait<String?>([
        _secretStorage.read(_deepseekApiKey),
        _secretStorage.read(_elevenLabsApiKey),
        _secretStorage.read(_tencentSecretIdKey),
        _secretStorage.read(_tencentSecretKey),
      ]);

      account.deepseekApiKey = _normalized(secrets[0]);
      account.elevenLabsApiKey = _normalized(secrets[1]);
      account.tencentSecretId = _normalized(secrets[2]);
      account.tencentSecretKey = _normalized(secrets[3]);

      account.ttsProvider = _enumByName(
        TtsProviderOption.values,
        preferences.getString(_ttsProviderKey),
        account.ttsProvider,
      );

      final storedVoiceGender = preferences.getString(_voiceGenderKey);
      account.voiceGender = storedVoiceGender == null
          ? null
          : _enumByName(
              Gender.values,
              storedVoiceGender,
              account.voiceGender ?? Gender.female,
            );
      account.elevenLabsVoiceId =
          _normalized(preferences.getString(_elevenLabsVoiceIdKey));
      account.tencentTtsRegion = _enumByName(
        TencentTtsRegion.values,
        preferences.getString(_tencentRegionKey),
        account.tencentTtsRegion,
      );

      account.hasValidDeepseekKey =
          (preferences.getBool(_deepseekValidKey) ?? false) &&
              account.deepseekApiKey != null;
      account.hasValidElevenLabsKey =
          (preferences.getBool(_elevenLabsValidKey) ?? false) &&
              account.elevenLabsApiKey != null;
      account.hasValidTencentKey =
          (preferences.getBool(_tencentValidKey) ?? false) &&
              account.tencentSecretId != null &&
              account.tencentSecretKey != null;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Could not load meditation service settings: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  /// Saves the latest account state. Rapid text-field changes are coalesced;
  /// the active write always drains the newest pending snapshot before it
  /// completes, so an older key prefix cannot overwrite a newer full key.
  Future<void> save(UserAccount account) {
    _pendingSnapshot = _ServiceSettingsSnapshot.fromAccount(account);
    return _saveLoop ??= _drainSaves();
  }

  /// Removes all stored credentials and restores neutral service defaults.
  ///
  /// An empty initialized snapshot is deliberately retained so deletion is a
  /// persisted state and cannot be confused with an incomplete write.
  Future<void> clear(UserAccount account) async {
    _pendingSnapshot = null;
    final activeSave = _saveLoop;
    if (activeSave != null) await activeSave;
    _pendingSnapshot = null;

    clearAccount(account);
    await _writeSnapshot(_ServiceSettingsSnapshot.fromAccount(account));
  }

  static void clearAccount(UserAccount account) {
    account
      ..deepseekApiKey = null
      ..hasValidDeepseekKey = false
      ..elevenLabsApiKey = null
      ..hasValidElevenLabsKey = false
      ..elevenLabsVoiceId = null
      ..availableElevenLabsVoices = null
      ..voiceGender = null
      ..ttsProvider = TtsProviderOption.elevenLabs
      ..tencentSecretId = null
      ..tencentSecretKey = null
      ..hasValidTencentKey = false
      ..tencentTtsRegion = TencentTtsRegion.internationalSingapore;
  }

  Future<void> _drainSaves() async {
    while (_pendingSnapshot != null) {
      final snapshot = _pendingSnapshot!;
      _pendingSnapshot = null;
      try {
        await _writeSnapshot(snapshot);
      } catch (error, stackTrace) {
        debugPrint('Could not save meditation service settings: $error');
        debugPrint('$stackTrace');
      }
    }
    _saveLoop = null;
  }

  Future<void> _writeSnapshot(_ServiceSettingsSnapshot snapshot) async {
    await _writeSecret(_deepseekApiKey, snapshot.deepseekApiKey);
    await _writeSecret(_elevenLabsApiKey, snapshot.elevenLabsApiKey);
    await _writeSecret(_tencentSecretIdKey, snapshot.tencentSecretId);
    await _writeSecret(_tencentSecretKey, snapshot.tencentSecretKey);

    final preferences = await _preferencesProvider();
    await preferences.setString(_ttsProviderKey, snapshot.ttsProvider.name);
    if (snapshot.voiceGender == null) {
      await preferences.remove(_voiceGenderKey);
    } else {
      await preferences.setString(
        _voiceGenderKey,
        snapshot.voiceGender!.name,
      );
    }
    if (snapshot.elevenLabsVoiceId == null) {
      await preferences.remove(_elevenLabsVoiceIdKey);
    } else {
      await preferences.setString(
        _elevenLabsVoiceIdKey,
        snapshot.elevenLabsVoiceId!,
      );
    }
    await preferences.setString(
      _tencentRegionKey,
      snapshot.tencentTtsRegion.name,
    );
    await preferences.setBool(
      _deepseekValidKey,
      snapshot.hasValidDeepseekKey,
    );
    await preferences.setBool(
      _elevenLabsValidKey,
      snapshot.hasValidElevenLabsKey,
    );
    await preferences.setBool(
      _tencentValidKey,
      snapshot.hasValidTencentKey,
    );
    // Written last: its presence means all values above form a saved config.
    await preferences.setBool(_initializedKey, true);
  }

  Future<void> _writeSecret(String key, String? value) {
    if (value == null) return _secretStorage.delete(key);
    return _secretStorage.write(key, value);
  }

  static String? _normalized(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static T _enumByName<T extends Enum>(
    Iterable<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

@immutable
class _ServiceSettingsSnapshot {
  final String? deepseekApiKey;
  final String? elevenLabsApiKey;
  final TtsProviderOption ttsProvider;
  final Gender? voiceGender;
  final String? elevenLabsVoiceId;
  final String? tencentSecretId;
  final String? tencentSecretKey;
  final TencentTtsRegion tencentTtsRegion;
  final bool hasValidDeepseekKey;
  final bool hasValidElevenLabsKey;
  final bool hasValidTencentKey;

  const _ServiceSettingsSnapshot({
    required this.deepseekApiKey,
    required this.elevenLabsApiKey,
    required this.ttsProvider,
    required this.voiceGender,
    required this.elevenLabsVoiceId,
    required this.tencentSecretId,
    required this.tencentSecretKey,
    required this.tencentTtsRegion,
    required this.hasValidDeepseekKey,
    required this.hasValidElevenLabsKey,
    required this.hasValidTencentKey,
  });

  factory _ServiceSettingsSnapshot.fromAccount(UserAccount account) {
    return _ServiceSettingsSnapshot(
      deepseekApiKey:
          MeditationServiceSettingsStore._normalized(account.deepseekApiKey),
      elevenLabsApiKey: MeditationServiceSettingsStore._normalized(
        account.elevenLabsApiKey,
      ),
      ttsProvider: account.ttsProvider,
      voiceGender: account.voiceGender,
      elevenLabsVoiceId: MeditationServiceSettingsStore._normalized(
        account.elevenLabsVoiceId,
      ),
      tencentSecretId: MeditationServiceSettingsStore._normalized(
        account.tencentSecretId,
      ),
      tencentSecretKey: MeditationServiceSettingsStore._normalized(
        account.tencentSecretKey,
      ),
      tencentTtsRegion: account.tencentTtsRegion,
      hasValidDeepseekKey: account.hasValidDeepseekKey,
      hasValidElevenLabsKey: account.hasValidElevenLabsKey,
      hasValidTencentKey: account.hasValidTencentKey,
    );
  }
}
