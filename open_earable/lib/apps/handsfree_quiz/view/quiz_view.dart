import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/handsfree_quiz/model/question.dart';
import 'package:open_earable/apps/handsfree_quiz/view/answer_view.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import '../model/position.dart';
import '../model/quiz.dart';
import '../model/sensor.dart';

class QuizView extends StatefulWidget {
  //Method that is needed so the
  final void Function(Quiz quiz) finalScore;
  final Quiz quiz;
  final OpenEarable _openEarable;

  const QuizView(this._openEarable,
      {required this.finalScore, required this.quiz});

  @override
  State<StatefulWidget> createState() => QuizState(_openEarable, quiz: quiz);
}

class QuizState extends State<QuizView> {
  final Quiz quiz;
  final OpenEarable _openEarable;
  late Question currentQuestion;
  bool currentAnswer = false;
  Positions _positions = Positions();
  List<Position> _data = <Position>[];
  late Sensor sensor;

  QuizState(this._openEarable, {required this.quiz}) {
    if (_openEarable.bleManager.connected) {
      sensor = new Sensor(_openEarable, this);
    }
    currentQuestion = quiz.currentQuestion();
  }

  void _answerQuestion(bool answer) {
    bool correct = false;
    if (quiz.questionsLeft()) {
      setState(() {
        correct = quiz.answerQuestion(answer);
        _data.clear();
        _answerReaction(correct, currentQuestion);
      });
    }
  }

  @override
  void initState() {
    setState(() {
      currentQuestion = quiz.currentQuestion();
    });
    super.initState();
  }

  /**
   * Method that on notification adds the current read Position and
   * tries to answer the current Question with the new Information
   */
  void updateData(Position position) {
    _positions.addPosition(position);
    print(position.toString());
    final Answer answer = _positions.computeAnswer();
    if (answer == Answer.yes) {
      sensor.stopListen();
      _answerQuestion(true);
    }
    if (answer == Answer.no) {
      sensor.stopListen();
      _answerQuestion(false);
    }
  }

  /**
   * Method to be Called from the AnswerView so the Quiz can be continued
   */
  void checkEnd() {
    /// Remove the AnswerView Widget
    Navigator.pop(context);
    /// Check if the Quiz has been finished
    if (!quiz.questionsLeft()) {
      _finishQuiz();
    }
    setState(() {
      currentQuestion = quiz.currentQuestion();
    });
    if (_openEarable.bleManager.connected) {
      sensor.startListen();
    }
  }

  /**
   * Create The AnswerView
   */
  void _answerReaction(bool correct, Question question) {
    Future pushed = Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => AnswerView(
              correct: correct,
              quizView: this,
              question: question,
            )));
    pushed.then((value) => () => checkEnd());
  }

  void _finishQuiz() {
    widget.finalScore(quiz);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Question " +
            quiz.currentIndex().toString() +
            "/" +
            quiz.numberQuestions.toString()),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The Current Question
          Text(
            currentQuestion.question,
            style: TextStyle(
              fontSize: 20,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            //Buttons to make the quiz Playable without the Earables
            children: [
              OutlinedButton(
                onPressed: () => _answerQuestion(true),
                child: Text(currentQuestion.firstAnswer),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Color(0xbb04aa6d),
                  foregroundColor: Colors.white,
                ),
              ),
              Container(
                width: 5,
              ),
              OutlinedButton(
                onPressed: () => _answerQuestion(false),
                child: Text(currentQuestion.secondAnswer),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Color(0xAAB01111),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bodyCreation() {


    return Placeholder();
  }


  @override
  void dispose() {
    /// since sensor is only initialized when openEarable is connected, it only
    /// needs to be disposed when openEarable is connected
    if (_openEarable.bleManager.connected) {
      sensor.dispose();
    }
    super.dispose();
  }
}
