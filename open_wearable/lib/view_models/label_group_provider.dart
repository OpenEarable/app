import 'package:flutter/foundation.dart';

import '../models/labels/label_group.dart';
import '../models/labels/label_group_manager.dart';

class LabelGroupProvider extends ChangeNotifier {
  LabelGroupProvider({LabelGroupManager? manager})
      : _manager = manager ?? LabelGroupManager() {
    _init();
  }

  final LabelGroupManager _manager;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  LabelGroup? _selectedLabelGroup;
  LabelGroup? get selectedLabelGroup => _resolveGroup(_selectedLabelGroup);

  List<LabelGroup> get labelGroups => _manager.labelGroups;

  Future<void> _init() async {
    await _manager.load();
    _selectedLabelGroup = _resolveGroup(_selectedLabelGroup);
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _manager.load();
    _selectedLabelGroup = _resolveGroup(_selectedLabelGroup);
    notifyListeners();
  }

  Future<void> addOrUpdateGroup(LabelGroup group) async {
    await _manager.upsertLabelGroup(group);
    if (_selectedLabelGroup?.name == group.name) {
      _selectedLabelGroup = group;
    }
    notifyListeners();
  }

  Future<void> deleteGroup(LabelGroup group) async {
    await _manager.removeLabelGroup(group);
    if (_selectedLabelGroup?.name == group.name) {
      _selectedLabelGroup = null;
    }
    notifyListeners();
  }

  Future<void> replaceGroup(LabelGroup oldGroup, LabelGroup newGroup) async {
    await _manager.replaceLabelGroup(oldGroup, newGroup);
    if (_selectedLabelGroup == oldGroup ||
        _selectedLabelGroup?.name == oldGroup.name) {
      _selectedLabelGroup = newGroup;
    }
    notifyListeners();
  }

  Future<void> clear() async {
    await _manager.clear();
    notifyListeners();
  }

  void selectLabelGroup(LabelGroup? group) {
    _selectedLabelGroup = _resolveGroup(group);
    notifyListeners();
  }

  LabelGroup? _resolveGroup(LabelGroup? group) {
    if (group == null) return null;
    for (final candidate in _manager.labelGroups) {
      if (candidate == group || candidate.name == group.name) {
        return candidate;
      }
    }
    return null;
  }
}
