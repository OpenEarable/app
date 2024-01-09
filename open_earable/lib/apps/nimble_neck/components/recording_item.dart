import 'package:flutter/material.dart';

import '../model/recording.dart';
import '../utils/number-utils.dart';
import 'recording_values.dart';

/// Dismissible list item for a [Recording]
class RecordingItem extends StatelessWidget {
  /// Recording to be displayed
  final Recording recording;

  /// Callback for when the item is dismissed
  final VoidCallback onDismissed;

  const RecordingItem(
      {super.key, required this.recording, required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(recording.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        onDismissed();
      },
      background: Container(
          padding: const EdgeInsets.only(right: 20.0),
          color: Colors.red,
          child: const Align(
            alignment: Alignment.centerRight,
            child: Text('Delete',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white)),
          )),
      child: ListTile(
        title: _buildTitle(),
        subtitle: RecordingValues(
          recording: recording,
        ),
      ),
    );
  }

  /// Returns the time and date of the [recording] in a [Text]
  Widget _buildTitle() {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Text(
        '${leadingZeroToDigit(recording.datetime.hour)}:${leadingZeroToDigit(recording.datetime.minute)}, ${recording.datetime.day} ${months[recording.datetime.month - 1]} ${recording.datetime.year}');
  }
}
