import 'package:flutter/material.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'pages/recordings_page.dart';

/// Sets the [RecordingsPage] as starting point
class NimbleNeckApp extends StatelessWidget {
  final OpenEarable _openEarable;

  const NimbleNeckApp(this._openEarable);

  @override
  Widget build(BuildContext context) {
    return RecordingsPage(_openEarable);
  }
}
