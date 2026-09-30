import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Coordinates wireless-audio configuration reads and writes for one device.
///
/// The controller keeps Bluetooth protocol operations out of the widget tree,
/// serializes mutations, and exposes a single listenable state for the page.
class WirelessAudioConfigurationController extends ChangeNotifier {
  /// Creates a controller backed by [manager].
  WirelessAudioConfigurationController(this.manager);

  /// Device capability used for all protocol operations.
  final WirelessAudioConfigurationManager manager;

  WirelessAudioConfigurationCapabilities? _capabilities;
  WirelessAudioConfigurationConfiguredAclConnectionPolicy? _aclConnection;
  WirelessAudioConfigurationConfiguredAclRadioPolicy? _aclRadio;
  WirelessAudioConfigurationConfiguredUnicastServerQosPreferences? _qos;
  WirelessAudioConfigurationRuntimeState? _runtimeState;
  StreamSubscription<WirelessAudioConfigurationRuntimeState>?
      _runtimeSubscription;
  Object? _loadError;
  bool _isLoading = false;
  bool _isMutating = false;
  bool _disposed = false;

  /// Capabilities reported by the device, or `null` until loading succeeds.
  WirelessAudioConfigurationCapabilities? get capabilities => _capabilities;

  /// Currently configured ACL connection policy, when readable.
  WirelessAudioConfigurationConfiguredAclConnectionPolicy? get aclConnection =>
      _aclConnection;

  /// Currently configured ACL radio policy, when readable.
  WirelessAudioConfigurationConfiguredAclRadioPolicy? get aclRadio => _aclRadio;

  /// Currently configured Unicast Server QoS preferences, when readable.
  WirelessAudioConfigurationConfiguredUnicastServerQosPreferences? get qos =>
      _qos;

  /// Most recently observed effective wireless-audio state.
  WirelessAudioConfigurationRuntimeState? get runtimeState => _runtimeState;

  /// Error that prevented the initial capability read.
  Object? get loadError => _loadError;

  /// Whether initial device data is being loaded.
  bool get isLoading => _isLoading;

  /// Whether a mutation is currently in flight.
  bool get isMutating => _isMutating;

  /// Loads capabilities, configuration, and the latest runtime snapshot.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;
    _notify();

    try {
      final capabilities = await manager.getCapabilities();
      _capabilities = capabilities;

      if (_supportsCommand(capabilities, 3)) {
        await _readSupportedConfiguration(capabilities);
      }

      try {
        _runtimeState = await manager.getRuntimeState();
      } catch (_) {
        // Runtime state is observational and must not make settings unusable.
      }

      if (_hasFeature(capabilities, 2)) {
        try {
          await _subscribeToRuntimeState();
        } catch (_) {
          // Settings remain usable when runtime notifications are unavailable.
        }
      }
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Writes [policy] as the device's ACL connection policy.
  Future<WirelessAudioConfigurationCommandResult> setAclConnectionPolicy(
    WirelessAudioConfigurationAclConnectionPolicy policy, {
    required bool persist,
  }) {
    return _mutate(() async {
      final result = await manager.setAclConnectionPolicy(
        policy,
        persist: persist,
      );
      _aclConnection = WirelessAudioConfigurationConfiguredAclConnectionPolicy(
        persisted: persist ? 1 : 0,
        policy: policy,
      );
      return result;
    });
  }

  /// Writes [policy] as the device's ACL radio policy.
  Future<WirelessAudioConfigurationCommandResult> setAclRadioPolicy(
    WirelessAudioConfigurationAclRadioPolicy policy, {
    required bool persist,
  }) {
    return _mutate(() async {
      final result = await manager.setAclRadioPolicy(
        policy,
        persist: persist,
      );
      _aclRadio = WirelessAudioConfigurationConfiguredAclRadioPolicy(
        persisted: persist ? 1 : 0,
        policy: policy,
      );
      return result;
    });
  }

  /// Writes the Unicast Server [preferences].
  Future<WirelessAudioConfigurationCommandResult> setQosPreferences(
    WirelessAudioConfigurationUnicastServerQosPreferences preferences, {
    required bool persist,
  }) {
    return _mutate(() async {
      final result = await manager.setUnicastServerQosPreferences(
        preferences,
        persist: persist,
      );
      _qos = WirelessAudioConfigurationConfiguredUnicastServerQosPreferences(
        persisted: persist ? 1 : 0,
        preferences: preferences,
      );
      return result;
    });
  }

  /// Restores compiled defaults for every section supported by the device.
  Future<WirelessAudioConfigurationCommandResult> restoreDefaults() {
    return _mutate(() async {
      final result = await manager.restoreDefaults();
      final capabilities = _capabilities;
      if (capabilities != null && _supportsCommand(capabilities, 3)) {
        await _readSupportedConfiguration(capabilities);
      }
      return result;
    });
  }

  Future<void> _readSupportedConfiguration(
    WirelessAudioConfigurationCapabilities capabilities,
  ) async {
    if (_supportsSection(capabilities, 0)) {
      try {
        _aclConnection = await manager.getAclConnectionPolicy();
      } catch (_) {
        // A supported section may still be temporarily unavailable.
      }
    }
    if (_supportsSection(capabilities, 1)) {
      try {
        _aclRadio = await manager.getAclRadioPolicy();
      } catch (_) {
        // Keep other independently readable sections available.
      }
    }
    if (_supportsSection(capabilities, 2)) {
      try {
        _qos = await manager.getUnicastServerQosPreferences();
      } catch (_) {
        // Keep other independently readable sections available.
      }
    }
  }

  Future<void> _subscribeToRuntimeState() async {
    await _runtimeSubscription?.cancel();
    final stream = await manager.subscribeToRuntimeState();
    _runtimeSubscription = stream.listen(
      (state) {
        _runtimeState = state;
        _notify();
      },
      onError: (_) {
        // A notification failure does not invalidate editable configuration.
      },
    );
  }

  Future<WirelessAudioConfigurationCommandResult> _mutate(
    Future<WirelessAudioConfigurationCommandResult> Function() operation,
  ) async {
    if (_isMutating) {
      throw StateError('A wireless audio configuration change is in progress.');
    }
    _isMutating = true;
    _notify();
    try {
      return await operation();
    } finally {
      _isMutating = false;
      _notify();
    }
  }

  bool _supportsSection(
    WirelessAudioConfigurationCapabilities capabilities,
    int bit,
  ) =>
      capabilities.supported_section_mask & (1 << bit) != 0;

  bool _supportsCommand(
    WirelessAudioConfigurationCapabilities capabilities,
    int bit,
  ) =>
      capabilities.supported_command_mask & (1 << bit) != 0;

  bool _hasFeature(
    WirelessAudioConfigurationCapabilities capabilities,
    int bit,
  ) =>
      capabilities.feature_flags & (1 << bit) != 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_runtimeSubscription?.cancel());
    super.dispose();
  }
}
