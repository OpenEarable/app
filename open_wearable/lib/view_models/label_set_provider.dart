import 'package:flutter/foundation.dart';

import '../models/labels/label_set.dart';
import '../models/labels/label_set_manager.dart';

class LabelSetProvider extends ChangeNotifier {
  LabelSetProvider({LabelSetManager? manager})
      : _manager = manager ?? LabelSetManager() {
    _init();
  }

  final LabelSetManager _manager;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  LabelSet? _selectedLabelSet;
  LabelSet? get selectedLabelSet => _resolveSet(_selectedLabelSet);

  List<LabelSet> get labelSets => _manager.labelSets;

  Future<void> _init() async {
    await _manager.load();
    _selectedLabelSet = _resolveSet(_selectedLabelSet);
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _manager.load();
    _selectedLabelSet = _resolveSet(_selectedLabelSet);
    notifyListeners();
  }

  Future<void> addOrUpdateSet(LabelSet set) async {
    await _manager.upsertLabelSet(set);
    if (_selectedLabelSet?.name == set.name) {
      _selectedLabelSet = set;
    }
    notifyListeners();
  }

  Future<void> deleteSet(LabelSet set) async {
    await _manager.removeLabelSet(set);
    if (_selectedLabelSet?.name == set.name) {
      _selectedLabelSet = null;
    }
    notifyListeners();
  }

  Future<void> replaceSet(LabelSet oldSet, LabelSet newSet) async {
    await _manager.replaceLabelSet(oldSet, newSet);
    if (_selectedLabelSet == oldSet || _selectedLabelSet?.name == oldSet.name) {
      _selectedLabelSet = newSet;
    }
    notifyListeners();
  }

  Future<void> clear() async {
    await _manager.clear();
    notifyListeners();
  }

  void selectLabelSet(LabelSet? set) {
    _selectedLabelSet = _resolveSet(set);
    notifyListeners();
  }

  LabelSet? _resolveSet(LabelSet? set) {
    if (set == null) return null;
    for (final candidate in _manager.labelSets) {
      if (candidate == set || candidate.name == set.name) {
        return candidate;
      }
    }
    return null;
  }
}
