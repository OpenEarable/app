import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'label_group.dart';
import 'label_group_storage.dart';

class FileLabelGroupStorage implements LabelGroupStorage {
  FileLabelGroupStorage({this.fileName = 'label_groups.json'});

  final String fileName;

  Future<File> _getFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, fileName));
  }

  @override
  Future<List<LabelGroup>> loadLabelGroups() async {
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
          .map((e) => LabelGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // In case of any error, return empty list instead of crashing.
      return [];
    }
  }

  @override
  Future<void> saveLabelGroups(List<LabelGroup> groups) async {
    final file = await _getFile();
    final jsonList = groups.map((group) => group.toJson()).toList();
    final content = jsonEncode(jsonList);
    await file.writeAsString(content);
  }
}

/// Factory used by conditional import.
LabelGroupStorage createLabelGroupStorage() => FileLabelGroupStorage();
