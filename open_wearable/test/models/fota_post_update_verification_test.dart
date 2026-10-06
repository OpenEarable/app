import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:open_wearable/view_models/app_banner_controller.dart';
import 'package:open_wearable/widgets/fota/stepper_view/update_view.dart';
import 'package:open_wearable/widgets/fota/fota_verification_banner.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/fota_post_update_verification.dart';

class _Capabilities implements StereoDevice, DeviceFirmwareVersion {
  final DevicePosition side;
  final Future<String?> Function() read;
  _Capabilities(this.side, this.read);
  @override
  Future<DevicePosition?> get position async => side;
  @override
  Future<String?> readDeviceFirmwareVersion() => read();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ear extends Wearable {
  @override
  final String deviceId;
  _Ear(this.deviceId, DevicePosition side, Future<String?> Function() read)
      : super(
          name: 'OpenEarable-Pair',
          disconnectNotifier: WearableDisconnectNotifier(),
        ) {
    final caps = _Capabilities(side, read);
    registerCapability<StereoDevice>(caps);
    registerCapability<DeviceFirmwareVersion>(caps);
  }
  @override
  Future<void> disconnect() async {}
}

FirmwareUpdateRequest request(String id) => FirmwareUpdateRequest(
      peripheral: SelectedPeripheral(name: 'OpenEarable-Pair', identifier: id),
      firmware: RemoteFirmware(
        name: '2.2.10',
        version: '2.2.10',
        url: 'https://example.test/fw.zip',
        type: FirmwareType.multiImage,
      ),
    );

class _CompletedBloc extends UpdateBloc {
  _CompletedBloc(FirmwareUpdateRequest request)
      : super(firmwareUpdateRequest: request);
  void show(UpdateFirmwareStateHistory state) => emit(state);
  void finish() => emit(
        UpdateFirmwareStateHistory(
          null,
          [UpdateCompleteSuccess()],
          isComplete: true,
        ),
      );
}

void main() {
  late FotaPostUpdateVerificationCoordinator coordinator;
  setUp(() {
    coordinator = FotaPostUpdateVerificationCoordinator();
  });
  for (final side in [DevicePosition.left, DevicePosition.right]) {
    testWidgets('verifies $side after reconnect', (tester) async {
      final id = side.toString();
      final armed = (await coordinator.armFromUpdateRequest(
        request: request(id),
        preResolvedSideLabel: side == DevicePosition.left ? 'L' : 'R',
      ))!;
      final result = await coordinator.verifyOnWearableConnected(
        _Ear(id, side, () async => '2.2.10-dev.67+gtest'),
      );
      expect(result!.success, isTrue);
      expect(coordinator.isVerificationPending(armed.verificationId), isFalse);
      expect(coordinator.resultFor(armed.verificationId), same(result));
    });
  }
  testWidgets('does not verify the other ear with the same pair name',
      (tester) async {
    final armed = (await coordinator.armFromUpdateRequest(
      request: request('right'),
      preResolvedSideLabel: 'R',
    ))!;
    expect(
      await coordinator.verifyOnWearableConnected(
        _Ear('left', DevicePosition.left, () async => '2.2.10'),
      ),
      isNull,
    );
    expect(coordinator.isVerificationPending(armed.verificationId), isTrue);
    expect(
      (await coordinator.verifyOnWearableConnected(
        _Ear('right', DevicePosition.right, () async => '2.2.10'),
      ))!
          .success,
      isTrue,
    );
  });
  testWidgets('reports the actual mismatched version', (tester) async {
    final armed = (await coordinator.armFromUpdateRequest(
      request: request('mismatch'),
      preResolvedSideLabel: 'L',
    ))!;
    final result = await coordinator.verifyOnWearableConnected(
      _Ear('mismatch', DevicePosition.left, () async => '2.2.9'),
    );
    expect(result!.success, isFalse);
    expect(result.message, contains('Expected 2.2.10 but detected 2.2.9'));
    expect(coordinator.isVerificationPending(armed.verificationId), isFalse);
  });
  testWidgets('concurrent reconnect callbacks read once and complete once',
      (tester) async {
    final read = Completer<String?>();
    var reads = 0;
    final ear = _Ear('duplicate', DevicePosition.right, () {
      reads++;
      return read.future;
    });
    await coordinator.armFromUpdateRequest(
      request: request('duplicate'),
      preResolvedSideLabel: 'R',
    );
    final first = coordinator.verifyOnWearableConnected(ear);
    final second = coordinator.verifyOnWearableConnected(ear);
    await tester.pump();
    expect(reads, 1);
    read.complete('2.2.10');
    final results = await Future.wait([first, second]);
    expect(results.whereType<FotaPostUpdateVerificationResult>(), hasLength(1));
  });
  testWidgets('no reconnect gives an explicit timeout, not success',
      (tester) async {
    final armed = (await coordinator.armFromUpdateRequest(
      request: request('timeout'),
      preResolvedSideLabel: 'L',
    ))!;
    await tester.pump(const Duration(minutes: 3));
    expect(coordinator.isVerificationPending(armed.verificationId), isFalse);
    final result = coordinator.resultFor(armed.verificationId)!;
    expect(result.success, isFalse);
    expect(result.message, contains('timed out'));
    expect(result.message, contains('not been verified'));
  });
  test('arming after reconnect triggers verification of the connected ear',
      () async {
    final ear = _Ear('early', DevicePosition.right, () async => '2.2.10');
    expect(await coordinator.verifyOnWearableConnected(ear), isNull);
    // The app subscribes to pending ids as well as connection events.
    final sub = coordinator.pendingVerificationIds.listen((ids) {
      if (ids.isNotEmpty) unawaited(coordinator.verifyOnWearableConnected(ear));
    });
    final armed = (await coordinator.armFromUpdateRequest(
      request: request('early'),
      preResolvedSideLabel: 'R',
    ))!;
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.resultFor(armed.verificationId)!.success, isTrue);
    await sub.cancel();
  });
  testWidgets('update screen shows verified and timeout results',
      (tester) async {
    coordinator = FotaPostUpdateVerificationCoordinator.instance;
    for (final timeout in [false, true]) {
      final provider = FirmwareUpdateRequestProvider();
      provider.updateParameters.peripheral =
          SelectedPeripheral(name: 'OpenEarable-Pair', identifier: 'screen');
      provider.setFirmware(
        RemoteFirmware(
          name: '2.2.10',
          version: '2.2.10',
          url: 'https://example.test/fw.zip',
          type: FirmwareType.multiImage,
        ),
      );
      final bloc = _CompletedBloc(provider.updateParameters);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(create: (_) => AppBannerController()),
            BlocProvider<UpdateBloc>.value(value: bloc),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child:
                    UpdateStepView(autoStart: false, preResolvedSideLabel: 'R'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      Set<String>? armedIds;
      final subscription = coordinator.pendingVerificationIds.listen((ids) {
        if (ids.isNotEmpty) armedIds = ids;
      });
      addTearDown(subscription.cancel);
      bloc.finish();
      await tester.pumpAndSettle();
      expect(
        armedIds,
        isNotNull,
        reason: 'Verification must be armed on upload success',
      );
      final id = armedIds!.single;
      expect(find.textContaining('Verification in progress'), findsOneWidget);
      if (timeout) {
        await tester.pump(const Duration(minutes: 3));
        await tester.pumpAndSettle();
        expect(find.textContaining('Verification timed out'), findsOneWidget);
      } else {
        await coordinator.verifyOnWearableConnected(
          _Ear('screen', DevicePosition.right, () async => '2.2.10'),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Update verified'), findsOneWidget);
      }
      expect(coordinator.isVerificationPending(id), isFalse);
      expect(find.textContaining('Verification in progress'), findsNothing);
      expect(find.textContaining('00:00'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    }
  });

  for (final outcome in [
    'verified',
    'mismatch',
    'timeout',
    'abort',
    'failure',
  ]) {
    testWidgets('reset shows a countdown and resolves on $outcome',
        (tester) async {
      coordinator = FotaPostUpdateVerificationCoordinator.instance;
      final original =
          _Ear('reset-$outcome', DevicePosition.right, () async => '2.3.0');
      final provider = FirmwareUpdateRequestProvider()
        ..setSelectedPeripheral(original)
        ..setFirmware(
          RemoteFirmware(
            name: '2.2.9',
            version: '2.2.9',
            url: 'https://example.test/fw.zip',
            type: FirmwareType.multiImage,
          ),
        );
      final bloc = _CompletedBloc(provider.updateParameters);
      final banners = AppBannerController();
      final running = <bool>[];
      addTearDown(bloc.close);
      addTearDown(provider.dispose);
      addTearDown(banners.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: banners),
            BlocProvider<UpdateBloc>.value(value: bloc),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: UpdateStepView(
                  autoStart: false,
                  preResolvedSideLabel: 'R',
                  onUpdateRunningChanged: running.add,
                ),
              ),
            ),
          ),
        ),
      );
      Set<String>? armedIds;
      final sub = coordinator.pendingVerificationIds.listen((ids) {
        if (ids.isNotEmpty) armedIds = ids;
      });
      addTearDown(sub.cancel);
      bloc.show(UpdateFirmwareStateHistory(UpdateFirmware('Validate'), []));
      await tester.pump();
      expect(armedIds, isNull, reason: 'Initial validation is before reboot');
      bloc.show(UpdateFirmwareStateHistory(UpdateFirmware('Reset'), [
        UpdateFirmware('Validate'),
      ]),);
      await tester.pump();
      expect(armedIds, isNull,
          reason: 'Recovery resets before upload must not verify',);
      expect(find.textContaining('Verification in progress'), findsNothing);
      expect(find.text('Abort Update'), findsOneWidget);
      if (outcome == 'verified') {
        bloc.show(UpdateFirmwareStateHistory(UpdateFirmware('Test'), [
          UpdateProgressFirmware('Upload', 100, 1),
        ]),);
        await tester.pump();
        await tester.tap(find.text('Abort Update'));
        await tester.pump(const Duration(milliseconds: 300));
      }
      bloc.show(
        UpdateFirmwareStateHistory(UpdateFirmware('Reset'), [
          UpdateProgressFirmware('Upload', 100, 1),
          UpdateFirmware('Test'),
        ]),
      );
      await tester.pump();
      await tester.pump();
      if (outcome == 'verified') {
        // A confirmation opened before reboot must no longer abort it.
        await tester.tap(find.text('Abort Update').last);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        armedIds,
        isNotNull,
        reason: 'Verification must start at Reset, before native success',
      );
      final id = armedIds!.single;
      expect(find.text('Reset and verify'), findsOneWidget);
      expect(find.textContaining('Verification in progress'), findsOneWidget);
      expect(find.text('Abort Update'), findsNothing);
      expect(find.textContaining(RegExp(r'0[23]:[0-5][0-9]')), findsOneWidget);
      expect(banners.activeBanners, hasLength(1));
      expect(running.last, isTrue);
      // main.dart rechecks already-connected wearables when verification arms.
      expect(await coordinator.verifyOnWearableConnected(original), isNull);
      expect(coordinator.isVerificationPending(id), isTrue);
      final deadline = tester
          .widget<FotaVerificationBanner>(find.byType(FotaVerificationBanner))
          .deadline;
      bloc.show(
        UpdateFirmwareStateHistory(UpdateFirmware('Reset'), [
          UpdateProgressFirmware('Upload', 100, 1),
          UpdateFirmware('Test'),
          UpdateFirmware('Reset'),
        ]),
      );
      await tester.pump(const Duration(seconds: 30));
      expect(armedIds, {id});
      expect(
        tester
            .widget<FotaVerificationBanner>(
              find.byType(FotaVerificationBanner),
            )
            .deadline,
        deadline,
      );
      if (outcome == 'timeout') {
        await tester.pump(const Duration(seconds: 150));
      } else if (outcome == 'abort' || outcome == 'failure') {
        bloc.show(
          UpdateFirmwareStateHistory(
            null,
            [
              outcome == 'abort'
                  ? UpdateCompleteAborted()
                  : UpdateCompleteFailure('Transport failed'),
            ],
            isComplete: true,
          ),
        );
      } else {
        await coordinator.verifyOnWearableConnected(
          _Ear(
            original.deviceId,
            DevicePosition.right,
            () async => outcome == 'verified' ? '2.2.9' : '2.3.0',
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(coordinator.isVerificationPending(id), isFalse);
      expect(find.textContaining('Verification in progress'), findsNothing);
      expect(find.text('Reset and verify'), findsNothing);
      expect(find.text('Abort Update'), findsNothing);
      expect(banners.activeBanners, isEmpty);
      expect(
        running.last,
        isFalse,
        reason:
            'A verified reconnect must release navigation before native success',
      );
      if (outcome == 'verified') {
        expect(
          find.textContaining('Update verified (version 2.2.9)'),
          findsOneWidget,
        );
        bloc.finish();
        await tester.pumpAndSettle();
        expect(armedIds, {id}, reason: 'Late native success must not rearm');
        expect(find.textContaining('Update verified'), findsOneWidget);
      } else if (outcome == 'mismatch') {
        expect(
          find.textContaining('Expected 2.2.9 but detected 2.3.0'),
          findsOneWidget,
        );
        expect(find.textContaining('Update verified'), findsNothing);
      } else if (outcome == 'timeout') {
        expect(find.textContaining('Verification timed out'), findsOneWidget);
        expect(find.textContaining('00:00'), findsNothing);
      } else {
        expect(coordinator.resultFor(id), isNull);
        expect(
          await coordinator.verifyOnWearableConnected(
            _Ear(
              original.deviceId,
              DevicePosition.right,
              () async => '2.2.9',
            ),
          ),
          isNull,
          reason: 'Cancelled checks must not verify on a later reconnect',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('upload is only marked complete once native upload finishes',
      (tester) async {
    final provider = FirmwareUpdateRequestProvider();
    final bloc = _CompletedBloc(request('upload'));
    addTearDown(bloc.close);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          BlocProvider<UpdateBloc>.value(value: bloc),
        ],
        child: const MaterialApp(
          home: Scaffold(body: UpdateStepView(autoStart: false)),
        ),
      ),
    );
    final unpack = UpdateFirmware('Unpack firmware');
    final uploadStarted = UpdateFirmware('Upload firmware');
    bloc.show(UpdateFirmwareStateHistory(uploadStarted, [unpack]));
    await tester.pump();
    expect(find.text('Upload firmware'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    for (final image in [0, 1]) {
      bloc.show(
        UpdateFirmwareStateHistory(
          UpdateProgressFirmware('Upload', 50 + image, image),
          [unpack, uploadStarted],
        ),
      );
      await tester.pump();
      expect(find.text('Upload firmware'), findsNothing);
      expect(find.text('Abort Update'), findsOneWidget);
      expect(
        find.text(
          'Uploading ${image == 0 ? 'application' : 'network'} core ${50 + image}%',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    }

    bloc.show(
      UpdateFirmwareStateHistory(
        UpdateFirmware('Test'),
        [unpack, uploadStarted, UpdateProgressFirmware('Upload', 100, 1)],
      ),
    );
    await tester.pump();
    expect(find.text('Upload firmware'), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
  });
}
