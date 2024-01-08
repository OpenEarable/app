import 'package:flutter/material.dart';
import 'package:open_earable/apps/handsfree_quiz/model/question.dart';

class QuestionAddForm extends StatefulWidget {
  final void Function(Question) onPressAdd;

  const QuestionAddForm({required this.onPressAdd, super.key});

  @override
  State<StatefulWidget> createState() => _QuestionAddFormState();
}

class _QuestionAddFormState extends State<QuestionAddForm> {
  @override
  void initState() {
    super.initState();
  }

  /// TextController which takes the Input for the Question
  final questionController = TextEditingController();
  final firstAnswerController = TextEditingController(text: "Yes");
  final secondAnswerController = TextEditingController(text: "No");

  /// DropDownValue that will be the Answer Value for the question
  bool _dropdownValue = true;

  @override
  void dispose() {
    questionController.dispose();
    super.dispose();
  }

  /**
   * Method that changes the dropDownValue
   */
  void dropDownCallback(bool? selectedValue) {
    if (selectedValue is bool) {
      setState(() {
        _dropdownValue = selectedValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return AlertDialog(
      title: Text("Add Question"),
      content: Column(
        children: [
          Text("Question: "),
          TextFormField(
            controller: questionController,
            autofocus: true,
          ),
          Text("First Answer: "),
          TextFormField(
            controller: firstAnswerController,
            autofocus: false,
          ),
          Text("Second Answer: "),
          TextFormField(
            controller: secondAnswerController,
            autofocus: false,
          ),
        ],
      ),
      actions: [
        DropdownButton(
          items: [
            DropdownMenuItem<bool>(child: Text("First Answer"), value: true),
            DropdownMenuItem<bool>(
              child: Text("Second Answer"),
              value: false,
            )
          ],
          value: _dropdownValue,
          onChanged: dropDownCallback,
        ),
        OutlinedButton(
          onPressed: () => _onPressedAction(),
          child: Text("Add"),
          style: OutlinedButton.styleFrom(
            backgroundColor: Color(0xAA000000),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /**
   * Creates the Question and Pops the Widget
   */
  void _onPressedAction() {
    Question question = Question(
        question: questionController.text,
        firstAnswer: firstAnswerController.text,
        secondAnswer: secondAnswerController.text,
        answer: _dropdownValue);
    widget.onPressAdd(question);
    Navigator.pop(context);
  }
}
