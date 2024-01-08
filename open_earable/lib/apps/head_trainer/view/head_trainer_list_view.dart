import 'package:flutter/material.dart';
import 'package:open_earable/apps/head_trainer/logic/orientation_value_updater.dart';
import 'package:open_earable/apps/head_trainer/model/orientation_value.dart';
import 'package:open_earable/apps/head_trainer/view/edit_sequence_view.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import '../model/sequence.dart';
import '../widget/button.dart';
import 'configure_head_view.dart';
import 'sequence_view.dart';

class HeadTrainerListView extends StatefulWidget {
  const HeadTrainerListView(this.openEarable);

  final OpenEarable openEarable;

  @override
  State<HeadTrainerListView> createState() => _HeadTrainerListViewState(openEarable);
}

class _HeadTrainerListViewState extends State<HeadTrainerListView> {

  OpenEarable _openEarable;
  List<Sequence> _sequences = [];

  _HeadTrainerListViewState(this._openEarable);

  late OrientationValueUpdater _oriValueUpdater;

  bool _shouldIgnoreError = false;

  _ignoreError() {
    setState(() {
      _shouldIgnoreError = true;
    });
  }

  _addSequence(Sequence sequence) {
    setState(() {
      _sequences.add(sequence);
    });
  }

  _removeSequence(Sequence sequence) {
    setState(() {
      _sequences.remove(sequence);
    });
  }

  _editSequence(Sequence oldSequence, Sequence newSequence) {
    setState(() {
      int index = _sequences.indexOf(oldSequence);
      _sequences.remove(oldSequence);
      _sequences.insert(index, newSequence);
    });
  }

  @override
  void initState() {
    _sequences.add(Sequence("Example Sequence", [
      Move(MoveType.tiltLeft, 20, 5, 5),
      Move(MoveType.tiltForward, 10, 5, 5),
      Move(MoveType.rotateRight, 45, 10, 15),
      Move(MoveType.rotateLeft, 30, 15, 15),
      Move(MoveType.tiltRight, 25, 8, 10),
      Move(MoveType.tiltBackwards, 15, 5, 8),
      Move(MoveType.rotateRight, 60, 12, 18),
      Move(MoveType.rotateLeft, 20, 10, 12),
    ]));

    _oriValueUpdater = OrientationValueUpdater(
      openEarable: _openEarable,
      yawDrift: 0,
      valueOffset: OrientationValue(),
    );

    if (_openEarable.bleManager.connected) {
      _oriValueUpdater.setupListeners();
    } else {
      _oriValueUpdater.setupMockListeners();
    }

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();

    _oriValueUpdater.stopListener();
  }
  
  @override
  Widget build(BuildContext context) {
    // Show an alert if the OpenEarable is not connected
    if (!_openEarable.bleManager.connected && !_shouldIgnoreError) {
      _notConnectAlert();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("Head Trainer"),
        actions: [
          IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ConfigureHeadView(
                    openEarable: _openEarable,
                    orientationValueUpdater: _oriValueUpdater,
                  )
              )),
              icon: Icon(Icons.settings)
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => EditSequenceView(onSave: _addSequence),
        )),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      body: _buildList()
    );
  }

  // Displays a list of sequences
  Widget _buildList() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: ListView.builder(
        itemCount: _sequences.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildSequenceCard(_sequences[index], context);
        },
      ),
    );
  }

  // Displays a card containing the name of the sequence and buttons to start,
  // edit or delete the sequence
  Widget _buildSequenceCard(Sequence sequence, BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                sequence.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => EditSequenceView(
                          sequence: sequence,
                          onSave: (newSequence) {
                            _editSequence(sequence, newSequence);
                          },
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.edit),
                ),
                IconButton(
                  onPressed: () {
                    _showDeleteDialog(sequence, context);
                  },
                  icon: Icon(Icons.delete),
                ),
                SizedBox(width: 12),
                Button(
                  text: "Start",
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => SequenceView(
                        sequence: sequence,
                        orientationValueUpdater: _oriValueUpdater,
                      )
                    ),
                  ),
                ),
              ],
            )
          ]
        ),
      ),
    );
  }

  // Displays alert that the OpenEarable is not connected
  Widget _notConnectAlert() {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.primary,
      title: Text("OpenEarable not connected"),
      content: Text("Please connect an OpenEarable before opening this app."),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Go Back",
                style: TextStyle(color: Colors.white))
        ),
        TextButton(
          onPressed: () => _ignoreError(),
          child: const Text("Ignore Error",
              style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }

  // Display dialog that asks if the user really wants to delete the sequence
  void _showDeleteDialog(Sequence sequence, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: Text("Delete this sequence?"),
          content: Text(
              "Do you want to delete the sequence \"${sequence.name}\"?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel", style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                _removeSequence(sequence);
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

}
