import 'dart:math';

import 'package:open_earable/apps/handsfree_quiz/model/question.dart';
import 'package:open_earable/apps/handsfree_quiz/model/score.dart';

/**
 * Quiz Object that organizes the Questions and in what way they have been
 * answered
 */
class Quiz {
  final List<Question> _questions = <Question>[];
  final List<Question> _answeredRight = <Question>[];
  final List<Question> _answeredWrong = <Question>[];
  final int numberQuestions;
  late Question _currentQuestion;

  Quiz({required List<Question> allQuestions, required this.numberQuestions}) {
    _pickRandom(allQuestions, numberQuestions);
    _currentQuestion = _questions[0];

  }

  /**
   * Picks the given number of questions from a list of questions
   * and puts them in _questions
   *
   * If numberQuestions is 0 or smaller _questions will be empty
   * If numberQuestions is larger then the length of list, _questions will be
   * empty
   * Otherwise _question.length will be numberQuestions
   *
   * list: List of Questions to be picked from
   * numberQuestions: number of Questions to be picked
   *
   */
  void _pickRandom(List<Question> list, numberQuestions) {
    /// check for legal input of numberQuestions
    if (list.length < numberQuestions || numberQuestions <= 0) {
      _questions.clear();
      return;
    } else if (list.length == numberQuestions) {
      _questions.addAll(list);
    }
    while (_questions.length < numberQuestions) {
      /// pick a random index for the question to pick
      final int index = Random().nextInt(list.length);
      /// don't add duplicate questions
      if (!_questions.contains(list[index])) {
        _questions.add(list[index]);
      }
    }

  }

  /**
   * Checks the Answer to the first question of _questions. The Question will be
   * removed from _questions and added to one of the answered lists
   *
   * If _questions is empty, this method returns false
   * Otherwise it will return whether the question was answered right
   *
   * answer: the bool answer that was given
   *
   */
  bool answerQuestion(bool answer) {
    if (_questions.isEmpty) return false;
    final Question question = _questions.removeAt(0);
    if (question.answer == answer) {
      _answeredRight.add(question);
    } else {
      _answeredWrong.add(question);
    }
    if(!_questions.isEmpty) {
      _currentQuestion = _questions[0];
    }
    return question.answer == answer;
  }

  /**
   * Checks if there are any questions left
   */
  bool questionsLeft() {
    return !_questions.isEmpty;
  }

  /**
   * Returns the first question in _questions, the question will
   * remain in the list
   *
   * If _questions doesn't contain elements, an Error will be thrown
   */
  Question currentQuestion() {
    return _currentQuestion;
  }

  /**
   * Getter for the wrong Answers
   */
  List<Question> getWrongAnswers() {
    return _answeredWrong;
  }

  /**
   * Getter for the right Answers
   */
  List<Question> getRightAnswers() {
    return _answeredRight;
  }

  /**
   * Returns a Score object for this Quiz
   */
  Score score() {
    final int maxScore = _answeredRight.length + _answeredWrong.length;
    return Score(score: _answeredRight.length, maxScore: maxScore);
  }

  /**
   * Shows which question you are on, NOT the index of the current Question
   */
  int currentIndex() {
    return min(numberQuestions - _questions.length + 1, numberQuestions);
  }
}
