import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/wearable_status_cache.dart';

class _Stereo implements StereoDevice {
  Future<DevicePosition?> Function() read;
  _Stereo(this.read);
  @override
  Future<DevicePosition?> get position => read();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wearable extends Wearable {
  _Wearable(_Stereo stereo)
      : super(
            name: 'OpenEarable-Pair',
            disconnectNotifier: WearableDisconnectNotifier(),) {
    registerCapability<StereoDevice>(stereo);
  }
  @override
  String get deviceId => 'ear';
  @override
  Future<void> disconnect() async {}
}

void main() {
  final cache = WearableStatusCache.instance;
  setUp(cache.clearAll);
  tearDown(cache.clearAll);
  test('unknown position is retried on the next view read', () async {
    var reads = 0;
    final ear = _Wearable(
        _Stereo(() async => ++reads == 1 ? null : DevicePosition.right),);
    expect(await cache.ensureStereoPosition(ear), isNull);
    expect(await cache.ensureStereoPosition(ear), DevicePosition.right);
    expect(await cache.ensureStereoPosition(ear), DevicePosition.right);
    expect(reads, 2);
  });
  test('failed position read is retried', () async {
    var reads = 0;
    final ear = _Wearable(_Stereo(() async {
      if (++reads == 1) throw StateError('Disconnected');
      return DevicePosition.left;
    }),);
    await expectLater(cache.ensureStereoPosition(ear), throwsStateError);
    expect(await cache.ensureStereoPosition(ear), DevicePosition.left);
  });
  test('concurrent reads share a pending request', () async {
    var reads = 0;
    final value = Completer<DevicePosition?>();
    final ear = _Wearable(_Stereo(() {
      reads++;
      return value.future;
    }),);
    final first = cache.ensureStereoPosition(ear);
    final second = cache.ensureStereoPosition(ear);
    expect(identical(first, second), isTrue);
    value.complete(DevicePosition.left);
    expect(await first, DevicePosition.left);
    expect(reads, 1);
  });
  for (final lateFailure in [false, true]) {
    test(
        'disconnected read cannot overwrite a reconnect (failure: $lateFailure)',
        () async {
      final old = Completer<DevicePosition?>();
      final fresh = Completer<DevicePosition?>();
      final oldEar = _Wearable(_Stereo(() => old.future));
      final newEar = _Wearable(_Stereo(() => fresh.future));
      final oldRead = cache.ensureStereoPosition(oldEar)!;
      final oldResult =
          lateFailure ? expectLater(oldRead, throwsStateError) : oldRead;
      cache.clearDevice(oldEar.deviceId);
      final newRead = cache.ensureStereoPosition(newEar);
      if (lateFailure) {
        old.completeError(StateError('Disconnected'));
      } else {
        old.complete(DevicePosition.left);
      }
      await oldResult;
      expect(identical(cache.ensureStereoPosition(newEar), newRead), isTrue);
      fresh.complete(DevicePosition.right);
      expect(await newRead, DevicePosition.right);
      expect(
          cache.cachedStereoPositionFor(newEar.deviceId), DevicePosition.right,);
    });
  }
}
