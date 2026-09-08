// Only used on web.
import 'dart:convert';
import 'package:web/web.dart' as web;

import 'label_group.dart';
import 'label_group_storage.dart';

class WebLabelGroupStorage implements LabelGroupStorage {
  WebLabelGroupStorage({this.storageKey = 'openwearable_label_groups'});

  final String storageKey;

  @override
  Future<List<LabelGroup>> loadLabelGroups() async {
    try {
      final stored = web.window.localStorage.getItem(storageKey);
      if (stored == null || stored.trim().isEmpty) {
        return [];
      }
      final jsonList = jsonDecode(stored) as List<dynamic>;
      return jsonList
          .map((e) => LabelGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveLabelGroups(List<LabelGroup> groups) async {
    final jsonList = groups.map((group) => group.toJson()).toList();
    final encoded = jsonEncode(jsonList);
    web.window.localStorage.setItem(storageKey, encoded);
  }
}

/// Factory used by conditional import.
LabelGroupStorage createLabelGroupStorage() => WebLabelGroupStorage();
