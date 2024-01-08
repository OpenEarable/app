import 'package:flutter/material.dart';
import 'package:open_earable/apps/handsfree_quiz//model/question.dart';
import 'package:open_earable/apps/handsfree_quiz//view/question_Manager.dart';
import 'package:open_earable/apps/handsfree_quiz//view/quiz_view.dart';
import 'package:open_earable/apps/handsfree_quiz//view/score_view.dart';
import 'package:open_earable/apps/handsfree_quiz//view/start_quiz_allert.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import '../model/quiz.dart';
import '../model/score.dart';

class HandsfreeQuiz extends StatefulWidget {
  final OpenEarable _openEarable;

  HandsfreeQuiz(this._openEarable);

  @override
  State<StatefulWidget> createState() => _HomeScreen(_openEarable);
}

class _HomeScreen extends State<HandsfreeQuiz> {
  /// Catalog that contains all questions that have been created
  final List<Question> catalog = <Question>[];
  final OpenEarable _openEarable;
  Score _score = Score(score: 0, maxScore: 0);

  _HomeScreen(this._openEarable);

  /**
   * Method that replaces the Catalog with a new List of Questions
   */
  void updateCatalog(List<Question> update) {
    setState(() {
      catalog.clear();
      catalog.addAll(update);
    });
  }

  /**
   * Method that returns a different List with the same content as catalog
   */
  List<Question> _copyCatalog() {
    List<Question> out = <Question>[];
    out.addAll(catalog);
    return out;
  }

  /**
   * Changes the highScore when necessary
   */
  void _changeScore(Score score) {
    if (score.isBetter(_score)) {
      setState(() {
        _score = score;
      });
    }
  }

  /**
   * Resets the HighScore to 0/0
   */
  void _resetScore() {
    setState(() {
      _score = Score(score: 0, maxScore: 0);
    });
  }

  /**
   * Pops the current Widget, changes to the ScoreView Widget and changes the
   * HighScore when needed
   */
  void _finishQuiz(Quiz quiz) {
    Navigator.pop(context);
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => ScoreView(quiz: quiz)));
    _changeScore(quiz.score());
  }

  /**
   * Method called by the startQuiz Alert which will be popped and the
   * QuizView will be opened with the chosen number of Questions
   */
  void _startQuiz(int numberQuestions) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizView(
          _openEarable,
          finalScore: _finishQuiz,
          quiz: Quiz(
            allQuestions: catalog,
            numberQuestions: numberQuestions,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("QuizApp"),
        ),
        body: Center(
          child: Column(
            children: [
              Column(
                children: [
                  Text(
                    "Number of Questions: " + catalog.length.toString(),
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(_scoreText(),
                      style: TextStyle(
                        fontSize: 20,
                      )),
                ],
                mainAxisAlignment: MainAxisAlignment.center,
              ),
              SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) => StartQuizAlert(
                          questionNumber: catalog.length,
                          onPressStart: _startQuiz));
                },
                child: Text('Play'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Color(0xbb04aa6d),
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton(
                onPressed: () => _resetScore(),
                child: Text('Reset score'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Color(0xAAB01111),
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => QuestionManager(
                            catalog: _copyCatalog(),
                            saveChanges: updateCatalog))),
                child: Text('Manage questions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.center,
          ),
        ));
  }

  String _scoreText() {
    return "HighScore: " + _score.scoreText;
  }
}
