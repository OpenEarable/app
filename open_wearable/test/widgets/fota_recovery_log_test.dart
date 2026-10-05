import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/fota/fota_slots_page.dart';
import 'package:open_wearable/widgets/fota/stepper_view/update_view.dart';
import 'package:provider/provider.dart';

class _Logger implements FirmwareUpdateLogger {
  final snapshot = Completer<List<McuLogMessage>>();
  bool disposed = false;
  int reads = 0;

  @override
  Stream<McuLogMessage> get logMessageStream => const Stream.empty();

  @override
  Future<List<McuLogMessage>> readLogs({bool clearLogs = false}) async {
    reads++;
    if (disposed) throw StateError('Update manager does not exist');
    return snapshot.future;
  }

  @override
  Future<void> clearLogs() async {}
}

class _Manager implements FirmwareUpdateManager {
  @override
  final _Logger logger = _Logger();
  final cancelCompleted = Completer<void>();
  bool cancelStarted = false;

  @override
  Future<void> cancel() {
    cancelStarted = true;
    return cancelCompleted.future;
  }

  @override
  Future<void> kill() async {
    logger.disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Bloc extends Cubit<UpdateState> implements UpdateBloc {
  final _Manager manager;
  _Bloc(this.manager) : super(UpdateInitial());

  void stage(String stage) => emit(
        UpdateFirmwareStateHistory(UpdateFirmware(stage), []),
      );

  @override
  void add(UpdateEvent event) {
    if (event is AbortUpdate) {
      manager.cancel().then((_) {
        if (!isClosed) {
          emit(
            UpdateFirmwareStateHistory(
              null,
              [UpdateCompleteAborted()],
              isComplete: true,
              updateManager: manager,
            ),
          );
        }
      });
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ear extends Wearable implements FotaSlotInfoCapability {
  final _Manager manager;
  int slotReads = 0;
  _Ear(this.manager)
      : super(name: 'ear', disconnectNotifier: WearableDisconnectNotifier());

  @override
  String get deviceId => 'ear';

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<FirmwareSlotInfo>> readFirmwareSlots() async {
    slotReads++;
    // The native slot reader shares and disposes this device's update manager.
    manager.logger.disposed = true;
    return [];
  }

  @override
  Future<void> eraseFirmwareSlot({int? channel}) async {}
}

void main() {
  for (final readFails in [false, true]) {
    testWidgets('recovery preserves the log result (read fails: $readFails)',
        (tester) async {
      final manager = _Manager();
      final ear = _Ear(manager);
      final provider = FirmwareUpdateRequestProvider()
        ..setSelectedPeripheral(ear);
      final bloc = _Bloc(manager);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(
                child: UpdateStepView(autoStart: false),
              ),
            ),
          ),
          GoRoute(
            path: '/fota/slots',
            builder: (_, __) => FotaSlotsPage(device: ear),
          ),
          GoRoute(path: '/view', builder: (_, state) => state.extra! as Widget),
        ],
      );
      addTearDown(bloc.close);
      addTearDown(() {
        if (!manager.cancelCompleted.isCompleted) {
          manager.cancelCompleted.complete();
        }
        if (!manager.logger.snapshot.isCompleted) {
          manager.logger.snapshot.complete([]);
        }
      });
      addTearDown(provider.dispose);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            BlocProvider<UpdateBloc>.value(value: bloc),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      for (final stage in ['Reset', 'Validate', 'Reset', 'Validate']) {
        bloc.stage(stage);
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Open Image Slots'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(ear.slotReads, 0, reason: 'Wait for cancellation before recovery');
      expect(manager.logger.reads, 0);
      expect(manager.cancelStarted, isTrue);

      manager.cancelCompleted.complete();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(manager.logger.reads, 1);
      expect(ear.slotReads, 0, reason: 'Preserve logs before slot inspection');
      if (readFails) {
        manager.logger.snapshot.completeError(StateError('Original log error'));
      } else {
        manager.logger.snapshot.complete([
          McuLogMessage(
            'Update cancelled; diagnostic details',
            McuMgrLogCategory.dfu,
            McuMgrLogLevel.info,
            DateTime(2026),
          ),
        ]);
      }
      await tester.pumpAndSettle();
      expect(ear.slotReads, 1);
      expect(manager.logger.disposed, isTrue);
      router.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Show Log'));
      await tester.tap(find.text('Show Log'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          readFails
              ? 'Original log error'
              : 'Update cancelled; diagnostic details',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Update manager does not exist'),
        findsNothing,
      );
      expect(manager.logger.reads, 1);
    });
  }
}
