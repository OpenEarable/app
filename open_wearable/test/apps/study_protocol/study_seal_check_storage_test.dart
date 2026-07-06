import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/study_protocol/model/study_seal_check_storage.dart';

void main() {
  test('stores a phase-scoped seal check with study metadata', () async {
    final directory = await Directory.systemTemp.createTemp('seal_check_test_');
    addTearDown(() => directory.delete(recursive: true));
    final measuredAt = DateTime.parse('2026-07-06T12:34:56.000');

    final path = await saveStudySealCheckResult(
      directory: directory.path,
      probandId: 'P 001',
      phase: 'baseline',
      position: 'start',
      measuredAt: measuredAt,
      result: {
        'left': {
          'quality': 87,
        },
        'right': {
          'quality': 91,
        },
      },
    );

    expect(path, endsWith('P_001_baseline_seal_check_start.json'));
    final json =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    expect(json['protocol'], 'DecoupEar');
    expect(json['proband_id'], 'P 001');
    expect(json['phase'], 'baseline');
    expect(json['position'], 'start');
    expect(json['measured_at'], measuredAt.toIso8601String());
    expect((json['left'] as Map<String, dynamic>)['quality'], 87);
    expect((json['right'] as Map<String, dynamic>)['quality'], 91);
  });

  test('a repeated check replaces the previous phase result', () async {
    final directory = await Directory.systemTemp.createTemp('seal_check_test_');
    addTearDown(() => directory.delete(recursive: true));

    final firstPath = await saveStudySealCheckResult(
      directory: directory.path,
      probandId: 'P001',
      phase: 'treadmill',
      position: 'end',
      result: {'left': 1},
    );
    final secondPath = await saveStudySealCheckResult(
      directory: directory.path,
      probandId: 'P001',
      phase: 'treadmill',
      position: 'end',
      result: {'left': 2},
    );

    expect(secondPath, firstPath);
    final files = await directory.list().where((entry) => entry is File).length;
    expect(files, 1);
    final json = jsonDecode(await File(secondPath).readAsString())
        as Map<String, dynamic>;
    expect(json['left'], 2);
  });
}
