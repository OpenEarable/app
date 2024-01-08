import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StartQuizAlert extends StatefulWidget {
  final int questionNumber;

  /// Method that starts the Quiz needs to be called here, but executed
  /// somewhere else
  final void Function(int numberQuestion) onPressStart;

  const StartQuizAlert(
      {super.key, required this.questionNumber, required this.onPressStart});

  @override
  State<StartQuizAlert> createState() =>
      _StartQuizAlertState(questionNumber: questionNumber);
}

class _StartQuizAlertState extends State<StartQuizAlert> {
  final int questionNumber;
  final numberController = TextEditingController();

  _StartQuizAlertState({required this.questionNumber});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Start Quiz"),
      content: TextField(
        decoration: InputDecoration(
            labelText: "How Many Questions? (Max amount: $questionNumber)",
            labelStyle: TextStyle(color: Colors.white)),
        keyboardType: TextInputType.number,
        /// Input should only be digits
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        controller: numberController,
        autofocus: true,
      ),
      actions: [
        TextButton(
            onPressed: _onPressedAction,
            child: Text(
              "Start",
              style: TextStyle(color: Colors.white),
            )),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: TextStyle(color: Colors.white),
          ),
        )
      ],
    );
  }

  /**
   * Starts the Quiz with the number Input, when the Input is out of range
   * the button will do nothing
   */
  void _onPressedAction() {
    /// Button pressed without content does nothing
    if(numberController.text == null) return;
    final int input = int.parse(numberController.text);
    assert(input is int);
    /// if input would be illegal for Quiz, button also does nothing
    if (questionNumber < input || input <= 0) return;
    /// start Quiz with input
    widget.onPressStart(input);
  }
}
