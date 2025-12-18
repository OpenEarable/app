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

  List<LabelSet> get labelSets => _manager.labelSets;

  Future<void> _init() async {
    await _manager.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _manager.load();
    notifyListeners();
  }

  Future<void> addOrUpdateSet(LabelSet set) async {
    await _manager.upsertLabelSet(set);
    notifyListeners();
  }

  Future<void> deleteSet(LabelSet set) async {
    await _manager.removeLabelSet(set);
    notifyListeners();
  }

  Future<void> replaceSet(LabelSet oldSet, LabelSet newSet) async {
    await _manager.replaceLabelSet(oldSet, newSet);
    notifyListeners();
  }

  Future<void> clear() async {
    await _manager.clear();
    notifyListeners();
  }
}
