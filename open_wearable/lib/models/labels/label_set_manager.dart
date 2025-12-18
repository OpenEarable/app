import 'package:flutter/foundation.dart';

import 'label_set.dart';

import 'label_set_storage.dart';
import 'file_label_set_storage.dart'
  if (dart.library.html) 'web_label_set_storage.dart';

class LabelSetManager extends ChangeNotifier {
  LabelSetManager({LabelSetStorage? storage})
      : _storage = storage ?? createLabelSetStorage();

  final LabelSetStorage _storage;

  final List<LabelSet> _labelSets = [];

  List<LabelSet> get labelSets => List.unmodifiable(_labelSets);

  /// Load label sets from persistent storage.
  Future<void> load() async {
    final loaded = await _storage.loadLabelSets();
    _labelSets
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  /// Persist current state.
  Future<void> _save() => _storage.saveLabelSets(_labelSets);

  /// Add a new label set (or replace one with the same name).
  Future<void> upsertLabelSet(LabelSet set) async {
    final index = _labelSets.indexWhere((s) => s.name == set.name);
    if (index >= 0) {
      _labelSets[index] = set;
    } else {
      _labelSets.add(set);
    }
    await _save();
    notifyListeners();
  }

  /// Remove a label set.
  Future<void> removeLabelSet(LabelSet set) async {
    _labelSets.removeWhere((s) => s.name == set.name);
    await _save();
    notifyListeners();
  }

  /// Replace one specific set with an updated instance.
  Future<void> replaceLabelSet(LabelSet oldSet, LabelSet newSet) async {
    final index = _labelSets.indexOf(oldSet);
    if (index >= 0) {
      _labelSets[index] = newSet;
      await _save();
      notifyListeners();
    }
  }

  /// Remove all label sets.
  Future<void> clear() async {
    _labelSets.clear();
    await _save();
    notifyListeners();
  }
}
