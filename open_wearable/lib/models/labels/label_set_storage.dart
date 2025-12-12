import 'dart:async';

import 'label_set.dart';

/// Interface for persisting label sets.
abstract class LabelSetStorage {
  Future<List<LabelSet>> loadLabelSets();
  Future<void> saveLabelSets(List<LabelSet> sets);
}
