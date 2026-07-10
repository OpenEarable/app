import 'dart:async';
import 'dart:math';

import 'package:open_wearable/app_store_preview.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude_tracker.dart';

class MockAttitudeTracker extends AttitudeTracker {
  Stream<Attitude> _attitudeStream = Stream.empty();
  StreamSubscription<Attitude>? _attitudeSubscription;
  final Attitude? _fixedAttitude;

  @override
  bool get isTracking =>
      _attitudeSubscription != null && !_attitudeSubscription!.isPaused;

  MockAttitudeTracker({
    Function(AttitudeTracker)? didChangeAvailability,
    Attitude? fixedAttitude,
  })
      : _fixedAttitude = fixedAttitude,
        super() {
    _attitudeStream = Stream.periodic(const Duration(milliseconds: 100), (count) {
      final fixedAttitude = AppStorePreviewWearable.isPostureImuFixedModeEnabled
          ? Attitude(
              roll: previewPostureFixedRollDegrees * pi / 180,
              pitch: previewPostureFixedPitchDegrees * pi / 180,
              yaw: 0,
            )
          : _fixedAttitude;
      if (fixedAttitude != null) {
        return Attitude(
          roll: fixedAttitude.roll,
          pitch: fixedAttitude.pitch,
          yaw: fixedAttitude.yaw,
        );
      }
      return Attitude(
          roll: sin(count / 10) * pi / 4,
          pitch: sin(count / 20) * pi / 4,
          yaw: sin(count / 30) * pi / 4,);
    });
    didChangeAvailability = didChangeAvailability ?? (_) {};

    didChangeAvailability(this);
    setAvailability(true);
  }

  @override
  void start() {
    if (_attitudeSubscription != null) {
      if (_attitudeSubscription!.isPaused) {
        _attitudeSubscription!.resume();
      }
      return;
    }

    _attitudeSubscription = _attitudeStream.listen((value) {
      updateAttitude(attitude: value);
    });
  }

  @override
  void stop() {
    _attitudeSubscription?.pause();
  }

  @override
  void cancel() {
    _attitudeSubscription?.cancel();
    super.cancel();
  }
}
