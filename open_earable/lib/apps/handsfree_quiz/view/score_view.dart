import 'package:flutter/material.dart';

import '../model/question.dart';
import '../model/quiz.dart';

class ScoreView extends StatelessWidget {
  final Quiz quiz;

  const ScoreView({super.key, required this.quiz});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Final Score"),
        ),
        body: Column(
          children: [
            Text(quiz.score().scoreText),
            Expanded(child: _buildAnswerList()),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "End",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ],
        ));
  }

  /**
   * List that shows all Questions, first the right answered Questions in green
   * and then the wrong answered Questions in red
   */
  Widget _buildAnswerList() {
    List<Question> questions = <Question>[];
    questions.addAll(quiz.getRightAnswers());
    questions.addAll(quiz.getWrongAnswers());
    return ListView.separated(
      itemCount: questions.length,
      itemBuilder: (BuildContext context, int index) {
        Color color = quiz.getRightAnswers().contains(questions[index])
            ? Colors.green
            : Colors.red;
        return Container(
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(" Question: " + questions[index].question),
              Text(" Answer: " + questions[index].answerText())
            ],
          ),
          color: color,
        );
      },
      separatorBuilder: (BuildContext context, int index) {
        return Divider(
          height: 0.5,
          color: Colors.white,
        );
      },
    );
  }
}
