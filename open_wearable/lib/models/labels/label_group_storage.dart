import 'dart:async';

import 'label_group.dart';

/// Interface for persisting label groups.
abstract class LabelGroupStorage {
  Future<List<LabelGroup>> loadLabelGroups();
  Future<void> saveLabelGroups(List<LabelGroup> groups);
}
