import 'package:flutter/material.dart';
import 'package:open_earable/apps/head_trainer/model/sequence.dart';
import 'package:open_earable/apps/head_trainer/view/new_move_view.dart';
import 'package:open_earable/apps/head_trainer/widget/text_input.dart';

import '../widget/button.dart';
import '../widget/move_card.dart';

class EditSequenceView extends StatefulWidget {
  const EditSequenceView({
    super.key,
    this.sequence = null,
    required this.onSave,
  });

  final Sequence? sequence;
  final Function(Sequence) onSave;

  @override
  State<EditSequenceView> createState() => _EditSequenceViewState(
      sequence, onSave);
}

class _EditSequenceViewState extends State<EditSequenceView> {

  final Sequence? _conSequence;
  final Function(Sequence) _onSave;

  late Sequence _sequence;
  late String _title;

  _EditSequenceViewState(this._conSequence, this._onSave) {
    if (_conSequence == null) {
      _sequence = Sequence("Title", List.empty(growable: true));
      _title = "New Sequence";
    } else {
      _sequence = _conSequence!.copy();
      _title = "Edit Sequence";
    }
  }

  _changeName(String newName) {
    setState(() {
      _sequence.name = newName;
    });
  }

  _addMove(Move move) {
    setState(() {
      _sequence.moves.add(move);
    });
  }

  _removeMove(Move move) {
    setState(() {
      _sequence.moves.remove(move);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            onPressed: () {
              _onSave(_sequence);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.save),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => NewMoveView(onSaved: _addMove),
        )),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 32, bottom: 64, left: 32, right: 32),
            child: GestureDetector(
              onTap: () {
                _showEditNameDialog();
              },
              child: Text(
                _sequence.name,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sequence.moves.length,
              itemBuilder: (BuildContext context, int index) {
                Move move = _sequence.moves[index];
                // Swipe to remove move
                return Dismissible(
                  key: UniqueKey(),
                  child: MoveCard(move: move),
                  background: Container(color: Colors.red),
                  onDismissed: (direction) {
                    _removeMove(move);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog() async {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.primary,
            title: const Text("Change Name"),
            content: TextInput(
              initialValue: _sequence.name,
              hintText: "Name of Sequence",
              onChanged: _changeName,
            ),
            actions: [
              Button(
                text: "Save",
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

}
