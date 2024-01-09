import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/recording_item.dart';
import '../model/recording.dart';
import 'add_recording_page.dart';

/// Displays the stored recordings
/// Lets the user delete the shown recordings
/// Lets the user navigate to [AddRecordingPage]
class RecordingsPage extends StatefulWidget {
  /// OpenEarable to use for recording
  final OpenEarable _openEarable;

  const RecordingsPage(this._openEarable);

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  final _prefKey = 'recordings';
  List<Recording> _recordings = [];

  @override
  void initState() {
    super.initState();
    loadRecordings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
      ),
      body: ListView.builder(
        itemCount: _recordings.length,
        itemBuilder: (context, index) {
          final recording = _recordings[index];
          return RecordingItem(
              recording: recording, onDismissed: () => _delete(recording));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AddRecordingPage(
                        openEarable: widget._openEarable,
                        saveRecording: _save,
                      )))
        },
        tooltip: 'Add Record',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Adds a [recording] to [_recordings]
  /// Stores the updated [_recordings]
  _save(Recording recording) {
    _recordings.add(recording);
    storeRecordings();
    setState(() {});
  }

  /// Deletes a [recording] in [_recordings]
  /// Stores the updated [_recordings]
  _delete(Recording recording) {
    _recordings =
        _recordings.where((element) => element.id != recording.id).toList();
    storeRecordings();
    setState(() {});
  }

  /// Loads the stored recordings from [SharedPreferences]
  /// Sets [_recordings] to the loaded recordings
  Future<void> loadRecordings() async {
    super.initState();
    final prefs = await SharedPreferences.getInstance();
    final encodedRecordings = prefs.getStringList(_prefKey);
    if (encodedRecordings == null) {
      return;
    }
    setState(() {
      _recordings = encodedRecordings
          .map((encodedRecording) => Recording.decode(encodedRecording))
          .toList();
    });
  }

  /// Stores all elements of [_recordings] in [SharedPreferences]
  /// Enables awaiting the recordings being stored
  Future<void> storeRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefKey, _recordings.map((recording) => recording.encode()).toList());
  }
}
