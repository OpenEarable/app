import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/labels/label.dart';
import '../models/labels/label_set.dart';

class LabelProvider with ChangeNotifier {
  LabelSet? labelSet;

  LabelProvider(this.labelSet);

  Label? _activeLabel;
  Label? get activeLabel => _activeLabel;

  /// Unix timestamp (milliseconds since epoch) when the active label was last set.
  int? _activeLabelSetAtUnixMs;
  int? get activeLabelSetAtUnixMs => _activeLabelSetAtUnixMs;

  final StreamController<(int, Label?)> _activeLabelController =
      StreamController<(int, Label?)>.broadcast();

  /// Emits a tuple of (unixTimeMs, activeLabel) whenever [setActiveLabel] is called.
  Stream<(int, Label?)> get activeLabelStream => _activeLabelController.stream;

  /// Sets the active label and records the unix time (ms) the label was set.
  ///
  /// This will:
  ///  - update [activeLabel] and [activeLabelSetAtUnixMs]
  ///  - notify listeners
  ///  - emit (timestamp, label) on [activeLabelStream]
  void setActiveLabel(Label? label, {int? unixTimeMs}) {
    final int ts = unixTimeMs ?? DateTime.now().millisecondsSinceEpoch;

    _activeLabel = label;
    _activeLabelSetAtUnixMs = ts;

    // Emit first so stream consumers can react immediately, then notify UI.
    if (!_activeLabelController.isClosed) {
      _activeLabelController.add((ts, label));
    }

    notifyListeners();
  }

  void setLabelSet(LabelSet? newLabelSet) {
    labelSet = newLabelSet;
    if (_activeLabel != null &&
        (labelSet == null || !labelSet!.labels.contains(_activeLabel))) {
      // Clear active label if it's not in the new label set.
      _activeLabel = null;
      _activeLabelSetAtUnixMs = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _activeLabelController.close();
    super.dispose();
  }
}
