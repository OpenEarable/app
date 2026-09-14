import 'package:flutter/foundation.dart';

import 'label_group.dart';

import 'label_group_storage.dart';
import 'file_label_group_storage.dart'
    if (dart.library.html) 'web_label_group_storage.dart';

class LabelGroupManager extends ChangeNotifier {
  LabelGroupManager({LabelGroupStorage? storage})
      : _storage = storage ?? createLabelGroupStorage();

  final LabelGroupStorage _storage;

  final List<LabelGroup> _labelGroups = [];

  List<LabelGroup> get labelGroups => List.unmodifiable(_labelGroups);

  /// Load label groups from persistent storage.
  Future<void> load() async {
    final loaded = await _storage.loadLabelGroups();
    _labelGroups
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  /// Persist current state.
  Future<void> _save() => _storage.saveLabelGroups(_labelGroups);

  /// Add a new label group (or replace one with the same name).
  Future<void> upsertLabelGroup(LabelGroup group) async {
    final index = _labelGroups.indexWhere((candidate) {
      return candidate.name == group.name;
    });
    if (index >= 0) {
      _labelGroups[index] = group;
    } else {
      _labelGroups.add(group);
    }
    await _save();
    notifyListeners();
  }

  /// Remove a label group.
  Future<void> removeLabelGroup(LabelGroup group) async {
    _labelGroups.removeWhere((candidate) => candidate.name == group.name);
    await _save();
    notifyListeners();
  }

  /// Replace one specific group with an updated instance.
  Future<void> replaceLabelGroup(
    LabelGroup oldGroup,
    LabelGroup newGroup,
  ) async {
    var index = _labelGroups.indexOf(oldGroup);
    if (index < 0) {
      index = _labelGroups.indexWhere((group) => group.name == oldGroup.name);
    }
    if (index >= 0) {
      _labelGroups[index] = newGroup;
      await _save();
      notifyListeners();
    }
  }

  /// Remove all label groups.
  Future<void> clear() async {
    _labelGroups.clear();
    await _save();
    notifyListeners();
  }
}
