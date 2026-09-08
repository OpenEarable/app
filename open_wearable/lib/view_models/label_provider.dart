import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/labels/label.dart';
import '../models/labels/label_group.dart';

class LabelProvider with ChangeNotifier {
  LabelGroup? labelGroup;

  LabelProvider(this.labelGroup);

  Label? _activeLabel;
  Label? get activeLabel => _activeLabel;

  /// Unix timestamp (milliseconds since epoch) when the active label was last set.
  int? _activeLabelSelectedAtUnixMs;
  int? get activeLabelSelectedAtUnixMs => _activeLabelSelectedAtUnixMs;

  final StreamController<(int, List<Label>)> _activeLabelController =
      StreamController<(int, List<Label>)>.broadcast();

  /// Emits a tuple of (unixTimeMs, activeLabel) whenever [setActiveLabel] is called.
  Stream<(int, List<Label>)> get activeLabelStream =>
      _activeLabelController.stream;

  /// Sets the active label and records the unix time (ms) the label was set.
  ///
  /// This will:
  ///  - update [activeLabel] and [activeLabelSelectedAtUnixMs]
  ///  - notify listeners
  ///  - emit (timestamp, label) on [activeLabelStream]
  void setActiveLabel(Label? label, {int? unixTimeMs}) {
    final int ts = unixTimeMs ?? DateTime.now().millisecondsSinceEpoch;

    _activeLabel = label;
    _activeLabelSelectedAtUnixMs = ts;

    // Emit first so stream consumers can react immediately, then notify UI.
    if (!_activeLabelController.isClosed) {
      _activeLabelController.add((ts, [if (label != null) label]));
    }

    notifyListeners();
  }

  void setLabelGroup(LabelGroup? newLabelGroup) {
    labelGroup = newLabelGroup;
    if (_activeLabel != null &&
        (labelGroup == null || !labelGroup!.labels.contains(_activeLabel))) {
      // Clear active label if it's not in the new label group.
      _activeLabel = null;
      _activeLabelSelectedAtUnixMs = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _activeLabelController.close();
    super.dispose();
  }
}
