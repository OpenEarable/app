// Covers the demographic prior blending into the measured baseline, and the
// connection tracking that keeps a session from running against an earbud
// that is not there.

import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/meditation_app/configs/bio_adaptive_mode_config.dart';
import 'package:open_wearable/apps/meditation_app/configs/demo_mode_config.dart';
import 'package:open_wearable/apps/meditation_app/model/bio_adaptive_session_config.dart';
import 'package:open_wearable/apps/meditation_app/model/measurement_phase.dart';
import 'package:open_wearable/apps/meditation_app/model/user_account.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/meditation_app/model/wearable_connection.dart';

void main() {
  UserAccount fullProfile() => UserAccount(
        age: 30,
        gender: Gender.male,
        fitnessLevel: FitnessLevel.moderate,
      );

  group('demographic prior', () {
    test('needs age, gender and fitness together', () {
      expect(fullProfile().demographicBaseline, isNotNull);

      // A missing field would otherwise leave a generic population default
      // standing in for it, which is not a prior worth blending.
      expect(
        UserAccount(gender: Gender.male, fitnessLevel: FitnessLevel.moderate)
            .demographicBaseline,
        isNull,
      );
      expect(
        UserAccount(age: 30, fitnessLevel: FitnessLevel.moderate)
            .demographicBaseline,
        isNull,
      );
      expect(
        UserAccount(age: 30, gender: Gender.male).demographicBaseline,
        isNull,
      );
      expect(UserAccount().demographicBaseline, isNull);
    });

    test('an empty profile still gets a fallback estimate elsewhere', () {
      // baselineBiometrics keeps its old job for sessions that never measure.
      final (heartRate, rmssd) = UserAccount().baselineBiometrics;
      expect(heartRate, greaterThan(0));
      expect(rmssd, greaterThan(0));
    });
  });

  group('baseline blending schedule', () {
    double? weight(Duration elapsed) =>
        BaselinePhase.demographicPriorWeight(elapsed);

    test('publishes nothing during the first minute', () {
      expect(weight(Duration.zero), isNull);
      expect(weight(const Duration(seconds: 59)), isNull);
    });

    test('falls from 70% to 30% across minutes one to five', () {
      expect(weight(const Duration(minutes: 1)), closeTo(0.7, 1e-9));
      expect(weight(const Duration(minutes: 2)), closeTo(0.6, 1e-9));
      expect(weight(const Duration(minutes: 3)), closeTo(0.5, 1e-9));
      expect(weight(const Duration(minutes: 4)), closeTo(0.4, 1e-9));
      expect(weight(const Duration(minutes: 5)), closeTo(0.3, 1e-9));
    });

    test('moves continuously between those anchors', () {
      expect(weight(const Duration(seconds: 90)), closeTo(0.65, 1e-9));
      expect(weight(const Duration(seconds: 210)), closeTo(0.45, 1e-9));
    });

    test('holds at 30% if the baseline runs long', () {
      expect(weight(const Duration(minutes: 9)), closeTo(0.3, 1e-9));
    });

    test('only the regular mode blends', () {
      expect(
        BioAdaptiveSessionConfig.standard.blendDemographicBaseline,
        isTrue,
      );
      expect(
        BioAdaptiveSessionConfig.conferenceDemo.blendDemographicBaseline,
        isFalse,
      );
      // The demo baseline is shorter than the schedule's first step anyway.
      expect(
        DemoModeConfig.baselineDuration,
        lessThan(BioAdaptiveModeConfig.demographicBlendStart),
      );
    });
  });

  group('blended values', () {
    test('the weight is the share held by the prior, not the data', () {
      // 70% prior at one minute: a 60 bpm prior against an 80 bpm measurement
      // sits nearer the prior.
      expect(BaselinePhase.blendValue(60, 80, 0.7), closeTo(66.0, 1e-9));
      // 30% prior at five minutes: nearer the measurement.
      expect(BaselinePhase.blendValue(60, 80, 0.3), closeTo(74.0, 1e-9));
    });

    test('the endpoints are the pure prior and the pure measurement', () {
      expect(BaselinePhase.blendValue(60, 80, 1.0), closeTo(60.0, 1e-9));
      expect(BaselinePhase.blendValue(60, 80, 0.0), closeTo(80.0, 1e-9));
    });
  });

  group('wearable connection', () {
    test('a session with no wearable is never treated as connected', () {
      final connection = WearableConnection(null);
      addTearDown(connection.dispose);
      expect(connection.isConnected, isFalse);
    });

    test('always-connected stands in where there is nothing to watch', () {
      final connection = WearableConnection.alwaysConnected();
      addTearDown(connection.dispose);
      expect(connection.isConnected, isTrue);
    });

    test('notifies once, and a stale callback after disposal is inert', () {
      // The SDK offers no way to remove a disconnect listener, so one left
      // behind by an earlier visit to the in-app must not fire into a
      // disposed notifier.
      final notifier = WearableDisconnectNotifier();
      final connection = WearableConnection(_FakeWearable(notifier));
      var notifications = 0;
      connection.addListener(() => notifications++);

      expect(connection.isConnected, isTrue);

      notifier.notifyListeners();
      expect(connection.isConnected, isFalse);
      expect(notifications, 1);

      notifier.notifyListeners();
      expect(notifications, 1, reason: 'already disconnected');

      connection.dispose();
      notifier.notifyListeners();
      expect(notifications, 1);
    });
  });
}

class _FakeWearable extends Wearable {
  _FakeWearable(WearableDisconnectNotifier notifier)
      : super(name: 'fake', disconnectNotifier: notifier);

  @override
  String get deviceId => 'fake-device';

  @override
  Future<void> disconnect() async {}
}
