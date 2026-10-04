import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wireless_audio_configuration_controller.dart';

void main() {
  group('WirelessAudioConfigurationController', () {
    test('loads supported configuration and observes runtime updates',
        () async {
      final manager = _FakeWirelessAudioConfigurationManager();
      final controller = WirelessAudioConfigurationController(manager);

      await controller.load();

      expect(controller.loadError, isNull);
      expect(controller.capabilities, same(manager.capabilities));
      expect(controller.aclConnection, same(manager.aclConnection));
      expect(controller.aclRadio, same(manager.aclRadio));
      expect(controller.qos, same(manager.qos));
      expect(controller.runtimeState?.sequence, 1);
      expect(manager.runtimeSubscriptionCount, 1);

      manager.runtimeStates.add(_runtimeState(sequence: 2));
      await Future<void>.delayed(Duration.zero);

      expect(controller.runtimeState?.sequence, 2);
      controller.dispose();
      await manager.dispose();
    });

    test('records successful writes and forwards persistence', () async {
      final manager = _FakeWirelessAudioConfigurationManager();
      final controller = WirelessAudioConfigurationController(manager);
      await controller.load();
      final policy =
          WirelessAudioConfigurationAclConnectionPolicy.fixedAclPolicy(
        WirelessAudioConfigurationFixedAclPolicy(
          interval_us: 15000,
          peripheral_latency: 0,
          supervision_timeout_ms: 4000,
        ),
      );

      await controller.setAclConnectionPolicy(policy, persist: true);

      expect(manager.lastAclPolicy, same(policy));
      expect(manager.lastPersist, isTrue);
      expect(controller.aclConnection?.policy, same(policy));
      expect(controller.aclConnection?.persisted, 1);
      expect(controller.isMutating, isFalse);
      controller.dispose();
      await manager.dispose();
    });

    test('keeps settings available when runtime observation fails', () async {
      final manager = _FakeWirelessAudioConfigurationManager(
        failRuntimeObservation: true,
      );
      final controller = WirelessAudioConfigurationController(manager);

      await controller.load();

      expect(controller.loadError, isNull);
      expect(controller.capabilities, isNotNull);
      expect(controller.aclConnection, isNotNull);
      controller.dispose();
      await manager.dispose();
    });
  });
}

class _FakeWirelessAudioConfigurationManager
    implements WirelessAudioConfigurationManager {
  _FakeWirelessAudioConfigurationManager({
    this.failRuntimeObservation = false,
  });

  final bool failRuntimeObservation;
  final runtimeStates =
      StreamController<WirelessAudioConfigurationRuntimeState>.broadcast();
  int runtimeSubscriptionCount = 0;
  bool? lastPersist;
  WirelessAudioConfigurationAclConnectionPolicy? lastAclPolicy;

  final capabilities = WirelessAudioConfigurationCapabilities(
    protocol_version: 1,
    supported_section_mask: 0x7,
    supported_command_mask: 0x1f,
    supported_acl_policy_mask: 0xf,
    supported_phy_mask: 0x7,
    minimum_acl_interval_us: 7500,
    maximum_acl_interval_us: 40000,
    acl_interval_resolution_us: 1250,
    maximum_acl_peripheral_latency: 30,
    minimum_acl_supervision_timeout_ms: 100,
    maximum_acl_supervision_timeout_ms: 32000,
    minimum_acl_data_octets: 27,
    maximum_acl_data_octets: 251,
    minimum_acl_data_time_us: 328,
    maximum_acl_data_time_us: 2120,
    supported_audio_direction_mask: 3,
    maximum_preferred_retransmission_number: 15,
    maximum_transport_latency_ms: 4000,
    minimum_presentation_delay_us: 0,
    maximum_presentation_delay_us: 4000000,
    feature_flags: 0x7,
  );

  late final aclConnection =
      WirelessAudioConfigurationConfiguredAclConnectionPolicy(
    persisted: 0,
    policy: WirelessAudioConfigurationAclConnectionPolicy
        .controllerDefaultAclPolicy(
      WirelessAudioConfigurationControllerDefaultAclPolicy(reserved: 0),
    ),
  );

  late final aclRadio = WirelessAudioConfigurationConfiguredAclRadioPolicy(
    persisted: 0,
    policy: WirelessAudioConfigurationAclRadioPolicy.automaticAclRadioPolicy(
      WirelessAudioConfigurationAutomaticAclRadioPolicy(reserved: 0),
    ),
  );

  late final qos =
      WirelessAudioConfigurationConfiguredUnicastServerQosPreferences(
    persisted: 0,
    preferences: _qosPreferences(),
  );

  Future<void> dispose() => runtimeStates.close();

  @override
  Future<WirelessAudioConfigurationCapabilities> getCapabilities() async =>
      capabilities;

  @override
  Future<WirelessAudioConfigurationRuntimeState> getRuntimeState() async {
    if (failRuntimeObservation) throw StateError('runtime unavailable');
    return _runtimeState(sequence: 1);
  }

  @override
  Future<Stream<WirelessAudioConfigurationRuntimeState>>
      subscribeToRuntimeState() async {
    if (failRuntimeObservation) throw StateError('notifications unavailable');
    runtimeSubscriptionCount += 1;
    return runtimeStates.stream;
  }

  @override
  Future<WirelessAudioConfigurationConfiguredAclConnectionPolicy>
      getAclConnectionPolicy() async => aclConnection;

  @override
  Future<WirelessAudioConfigurationConfiguredAclRadioPolicy>
      getAclRadioPolicy() async => aclRadio;

  @override
  Future<WirelessAudioConfigurationConfiguredUnicastServerQosPreferences>
      getUnicastServerQosPreferences() async => qos;

  @override
  Future<WirelessAudioConfigurationCommandResult> setAclConnectionPolicy(
    WirelessAudioConfigurationAclConnectionPolicy policy, {
    bool persist = false,
  }) async {
    lastAclPolicy = policy;
    lastPersist = persist;
    return _successResult();
  }

  @override
  Future<WirelessAudioConfigurationCommandResult> setAclRadioPolicy(
    WirelessAudioConfigurationAclRadioPolicy policy, {
    bool persist = false,
  }) async =>
      _successResult();

  @override
  Future<WirelessAudioConfigurationCommandResult>
      setUnicastServerQosPreferences(
    WirelessAudioConfigurationUnicastServerQosPreferences preferences, {
    bool persist = false,
  }) async =>
          _successResult();

  @override
  Future<WirelessAudioConfigurationCommandResult> restoreDefaults({
    Set<WirelessAudioConfigurationSection> sections = const {},
  }) async =>
      _successResult();
}

WirelessAudioConfigurationCommandResult _successResult() {
  return WirelessAudioConfigurationCommandResult(
    status: 0,
    error_domain: 0,
    error_code: 0,
    restart_required_mask: 0,
  );
}

WirelessAudioConfigurationUnicastServerQosPreferences _qosPreferences() {
  return WirelessAudioConfigurationUnicastServerQosPreferences(
    direction_mask: 3,
    unframed_supported: 1,
    preferred_phy_mask: 2,
    preferred_retransmission_number: 2,
    maximum_transport_latency_ms: 20,
    minimum_presentation_delay_us: 10000,
    maximum_presentation_delay_us: 40000,
    preferred_minimum_presentation_delay_us: 20000,
    preferred_maximum_presentation_delay_us: 30000,
  );
}

WirelessAudioConfigurationRuntimeState _runtimeState({required int sequence}) {
  return WirelessAudioConfigurationRuntimeState(
    sequence: sequence,
    validity_flags: 0x7f,
    connection_id: 3,
    stream_id: 1,
    direction: 0,
    lifecycle_state: 5,
    acl_interval_us: 15000,
    acl_peripheral_latency: 0,
    acl_supervision_timeout_ms: 4000,
    transmit_phy: 2,
    receive_phy: 2,
    transmit_data_octets: 251,
    receive_data_octets: 251,
    lc3_sampling_frequency_hz: 48000,
    lc3_frame_duration_us: 10000,
    lc3_octets_per_frame: 100,
    lc3_frame_blocks_per_sdu: 1,
    lc3_channel_allocation: 1,
    iso_sdu_interval_us: 10000,
    iso_framing: 0,
    iso_phy: 2,
    iso_retransmission_number: 2,
    iso_maximum_sdu_octets: 100,
    iso_maximum_transport_latency_ms: 20,
    presentation_delay_us: 30000,
    audio_underrun_count: 0,
    acl_adjustment_count: 0,
  );
}
