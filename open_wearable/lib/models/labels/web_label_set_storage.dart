// Only used on web.
import 'dart:convert';
import 'package:web/web.dart' as web;

import 'label_set.dart';
import 'label_set_storage.dart';

class WebLabelSetStorage implements LabelSetStorage {
  WebLabelSetStorage({this.storageKey = 'openwearable_label_sets'});

  final String storageKey;

  @override
  Future<List<LabelSet>> loadLabelSets() async {
    try {
      final stored = web.window.localStorage.getItem(storageKey);
      if (stored == null || stored.trim().isEmpty) {
        return [];
      }
      final jsonList = jsonDecode(stored) as List<dynamic>;
      return jsonList
          .map((e) => LabelSet.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveLabelSets(List<LabelSet> sets) async {
    final jsonList = sets.map((s) => s.toJson()).toList();
    final encoded = jsonEncode(jsonList);
    web.window.localStorage.setItem(storageKey, encoded);
  }
}

/// Factory used by conditional import.
LabelSetStorage createLabelSetStorage() => WebLabelSetStorage();
