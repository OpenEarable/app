import 'package:flutter/material.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'pages/recordings_page.dart';

/// Sets the [RecordingsPage] as starting point
class NimbleNeck extends StatelessWidget {
  final OpenEarable _openEarable;

  const NimbleNeck(this._openEarable);

  @override
  Widget build(BuildContext context) {
    return RecordingsPage(_openEarable);
  }
}
