import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/log_file_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('shared app and library loggers rotate a file once', () async {
    final directory =
        await Directory.systemTemp.createTemp('wearable-log-test-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    messenger.setMockMethodCallHandler(channel, (call) async => directory.path);
    final timers = <Timer>[];
    final rotations = <void Function()>[];
    final messages = <String>[];
    LogFileManager? manager;
    try {
      await runZoned(
        () async {
          manager = await LogFileManager.create();
          await Future.wait([manager!.logger.init, manager!.libLogger.init]);
          final latest = File('${manager!.logDirectoryPath}/latest.log');
          await latest.writeAsString(
            'x' * (1100 * 1024),
            mode: FileMode.append,
          );
          for (final rotate in rotations) {
            rotate();
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
          manager!.logger.w('APP-AFTER-ROTATION');
          manager!.libLogger.w('LIB-AFTER-ROTATION');
          await Future<void>.delayed(const Duration(milliseconds: 100));
        },
        zoneSpecification: ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, duration, callback) {
            final timer = parent.createPeriodicTimer(zone, duration, callback);
            timers.add(timer);
            if (duration == const Duration(minutes: 1)) {
              rotations.add(() => callback(timer));
            }
            return timer;
          },
          print: (self, parent, zone, line) => messages.add(line),
        ),
      );
      final errors =
          messages.where((s) => s.contains('PathNotFoundException')).toList();
      print(
        'Rotation timers: ${rotations.length}; missing-file errors: ${errors.length}',
      );
      expect(
        errors,
        isEmpty,
        reason: 'Sharing an output must not race renaming latest.log',
      );
      expect(
        rotations,
        hasLength(1),
        reason: 'One output needs one rotation lifecycle',
      );
      manager!.dispose();
      await Future.wait(
        [manager!.logger.close(), manager!.libLogger.close()],
      );
      expect(
        timers.where((timer) => timer.isActive),
        isEmpty,
        reason: 'Disposal must cancel every shared output timer',
      );
      final files = await manager!.logFiles;
      expect(
        files,
        hasLength(2),
        reason: 'Keep one rotated file and latest.log',
      );
      final contents =
          (await Future.wait(files.map((file) => file.readAsString()))).join();
      expect('APP-AFTER-ROTATION'.allMatches(contents), hasLength(1));
      expect('LIB-AFTER-ROTATION'.allMatches(contents), hasLength(1));
      manager = null;
    } finally {
      for (final timer in timers) {
        timer.cancel();
      }
      if (manager != null) {
        manager!.dispose();
        await Future.wait(
          [manager!.logger.close(), manager!.libLogger.close()],
        );
      }
      messenger.setMockMethodCallHandler(channel, null);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await directory.delete(recursive: true);
    }
  });
}
