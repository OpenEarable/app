import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'label_set.dart';
import 'label_set_storage.dart';

class FileLabelSetStorage implements LabelSetStorage {
  FileLabelSetStorage({this.fileName = 'label_sets.json'});

  final String fileName;

  Future<File> _getFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, fileName));
  }

  @override
  Future<List<LabelSet>> loadLabelSets() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }
      final jsonList = jsonDecode(content) as List<dynamic>;
      return jsonList
          .map((e) => LabelSet.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // In case of any error, return empty list instead of crashing.
      return [];
    }
  }

  @override
  Future<void> saveLabelSets(List<LabelSet> sets) async {
    final file = await _getFile();
    final jsonList = sets.map((s) => s.toJson()).toList();
    final content = jsonEncode(jsonList);
    await file.writeAsString(content);
  }
}

/// Factory used by conditional import.
LabelSetStorage createLabelSetStorage() => FileLabelSetStorage();
