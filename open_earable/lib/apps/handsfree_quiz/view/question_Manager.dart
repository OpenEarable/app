import 'package:flutter/material.dart';
import 'package:open_earable/apps/handsfree_quiz/view/question_add_alert.dart';

import '../model/question.dart';

class QuestionManager extends StatefulWidget {
  final List<Question> catalog;

  ///Method to save The changes needs to be called here, but doesn't need to be
  ///executed here
  final void Function(List<Question>) saveChanges;

  const QuestionManager({required this.catalog, required this.saveChanges});

  @override
  State<StatefulWidget> createState() => QuestionManagerState(catalog: catalog);
}

class QuestionManagerState extends State<QuestionManager> {
  /// The Catalogue with the Questions
  final List<Question> catalog;

  QuestionManagerState({required this.catalog});

  /**
   * Adds a Question to the Catalog
   */
  void _addQuestion(Question question) {
    if (catalog.contains(question)) return;
    setState(() {
      catalog.add(question);
    });
  }

  /**
   * Removes a Question from the Catalog
   */
  void _removeQuestion(Question question) {
    if (!catalog.contains(question)) return;
    setState(() {
      final int index = catalog.indexWhere((element) => element == question);
      catalog.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Edit Questions"),
      ),
      body: Center(
          child: Column(children: [
        Expanded(child: _questionList()),
        /// Save Button that calls the given save function and pops this Widget
        OutlinedButton(
          onPressed: () {
            widget.saveChanges(catalog);
            Navigator.pop(context);
          },
          child: Text("Save"),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        Container(
          height: 10,
        )
      ])),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => QuestionAddForm(onPressAdd: _addQuestion),
          );
        },
        backgroundColor: Color(0xbb04aa6d),
        child: const Icon(Icons.add),
      ),
    );
  }

  /**
   * A List of all Question Items
   */
  Widget _questionList() {
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      itemCount: catalog.length,
      itemBuilder: (BuildContext context, int index) {
        return Container(
          child: _questionItem(index),
        );
      },
    );
  }

  /**
   * Question Item that Contains of the String representation of the Question
   * and a Button to delete the Question
   */
  Widget _questionItem(int i) {
    return Row(
      children: [
        Expanded(child: Text(catalog[i].question)),
        SizedBox(width: 5,),
        Expanded(child: Text(catalog[i].answerText())),
        Expanded(
            child: OutlinedButton(
          onPressed: () => _removeQuestion(catalog[i]),
          child: Text("Delete"),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        )),
      ],
    );
  }
}
