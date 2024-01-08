import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/handsfree_quiz/model/question.dart';
import 'package:open_earable/apps/handsfree_quiz/view/quiz_view.dart';

/**
 * The AnswerView is the Widget shown after a question has been answered
 */
class AnswerView extends StatefulWidget {
  final bool correct;
  final QuizState quizView;
  final Question question;

  const AnswerView(
      {super.key,
      required bool this.correct,
      required this.question,
      required this.quizView});

  AnswerState createState() =>
      AnswerState(correct: correct, question: question, quizView: quizView);
}

class AnswerState extends State {
  final bool correct;
  final QuizState quizView;
  final Question question;

  AnswerState(
      {required bool this.correct,
      required this.question,
      required this.quizView});

  @override
  void initState() {
    super.initState();

    /// after 3 seconds continue with the Quiz
    Timer(Duration(seconds: 3), () {
      if (mounted) {
        quizView.checkEnd();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Set color and Text depending on the Answer
    Color backGround = correct ? Colors.green : Colors.red;
    String rightWrong = correct ? "right" : "wrong";
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        color: backGround,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              rightWrong,
              style: TextStyle(fontSize: 20),
            ),
            Container(height: 20),
            Text(
              "Correct Answer: " + question.answerText(),
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
