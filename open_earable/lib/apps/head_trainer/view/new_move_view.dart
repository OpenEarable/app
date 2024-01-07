import 'package:flutter/material.dart';
import 'package:open_earable/apps/head_trainer/model/sequence.dart';

import '../widget/button.dart';
import '../widget/text_input.dart';

class NewMoveView extends StatefulWidget {
  const NewMoveView({super.key, required this.onSaved});

  final Function(Move) onSaved;

  @override
  State<NewMoveView> createState() => _NewMoveViewState(this.onSaved);
}

class _NewMoveViewState extends State<NewMoveView> {

  final Function(Move) onSaved;

  _NewMoveViewState(this.onSaved);

  MoveType _type = MoveType.tiltLeft;
  int _amountInDegree = 0;
  int _timeInSeconds = 0;

  _setType(MoveType type) {
    setState(() {
      _type = type;
    });
  }

  _setAmount(int amountInDegree) {
    setState(() {
      _amountInDegree = amountInDegree;
    });
  }

  _setTime(int timeInSeconds) {
    setState(() {
      _timeInSeconds = timeInSeconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text("New Move"),
        actions: [],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Column(
              children: [
                _buildRow(
                  title: "Type",
                  description: "Type of movement",
                  child: _buildDropdownMenu(),
                ),
                _buildRow(
                  title: "Amount",
                  description: "Amount of movement that is required in degrees",
                  child: TextInput(
                    initialValue: _amountInDegree.toString(),
                    hintText: "Amount in Degree",
                    onChanged: (value) {
                      _setAmount(int.parse(value));
                    },
                    keyboardType: TextInputType.number,
                  ),
                ),
                _buildRow(
                  title: "Time",
                  description: "Time the move should be held for in seconds",
                  child: TextInput(
                    initialValue: _timeInSeconds.toString(),
                    hintText: "Time in Seconds",
                    onChanged: (value) {
                      _setTime(int.parse(value));
                    },
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: Button(
                text: "Add Move",
                onPressed: () {
                  onSaved(Move.defaultPM(_type, _amountInDegree, _timeInSeconds));
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      )
    );
  }

  Widget _buildDropdownMenu() {
    return DropdownMenu(
      // TODO: fix hardcoded width
      width: 140,
      initialSelection: _type,
      onSelected: (value) {
        if (value?.type == "Rotate") {
          _showRotationWarning(context);
        }
        _setType(value!);
      },
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.all(10),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: Colors.white,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.onSurfaceVariant
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.primary,
      ),
      dropdownMenuEntries: MoveType.values.map((type) {
        return DropdownMenuEntry(
          value: type,
          label: type.type + " " + type.direction
        );
      }).toList(),
    );
  }

  void _showRotationWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: Text("Rotate Move Unreliable"),
          content: Text(
              "Please note that tracking the rotation "
                  "of the OpenEarable may be unreliable."),
          actions: <Widget>[
            TextButton(
              child: Text(
               "Ok",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow({
    required String title,
    required String description,
    required Widget child
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: EdgeInsets.only(right: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          description,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              Expanded(
                  flex: 3,
                  child: child
              )
            ],
          ),
        ),
      ),
    );
  }

}
