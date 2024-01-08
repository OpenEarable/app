import 'package:flutter/material.dart';
import 'package:open_earable/apps/quizzmee/model/answer.dart';
import 'package:open_earable/apps/quizzmee/model/question.dart';
import 'package:open_earable/apps/quizzmee/model/quiz.dart';

// QuizzmeeViewModel manages the state and logic of the Quizzmee app.
class QuizzmeeViewModel extends ChangeNotifier {
  late Quiz quiz; // The quiz object containing all questions and answers.
  int currentQuestionIndex = 0;
  bool? selectedAnswerCorrect;
  Answer? selectedAnswer;
  int score = 0; // Track the number of correct answers
  bool isQuizFinished = false;
  bool isHeadTiltActive = false;

  // Constructor to initialize the quiz with mock data.
  QuizzmeeViewModel() {
    initializeQuizWithMockData();
  }

  // Getter to retrieve the current question from the quiz.
  Question get currentQuestion => quiz.questions[currentQuestionIndex];

  // Handles the logic when an answer is selected.
  void handleAnswerSelection(Answer answer) async {
    selectedAnswer = answer;
    selectedAnswerCorrect = answer.isCorrect;
    deactivateHeadTilt();
    notifyListeners();

    await Future.delayed(Duration(seconds: 2)); // Show feedback

    if (selectedAnswerCorrect == true) {
      score++; // Increment score for correct answers
      if (++currentQuestionIndex >= quiz.questions.length) {
        endQuiz(); // End quiz if there are no more questions
      } else {
        // Reset for next question
        selectedAnswer = null;
        selectedAnswerCorrect = null;
        notifyListeners(); // Notify to update UI for next question
        activateHeadTilt();
      }
    } else {
      endQuiz();
    }
  }

  void activateHeadTilt() {
    isHeadTiltActive = true;
    notifyListeners();
  }

  void deactivateHeadTilt() {
    isHeadTiltActive = false;
    notifyListeners();
  }

  // Ends the quiz and resets necessary properties.
  void endQuiz() {
    isQuizFinished = true;
    currentQuestionIndex = 0;
    selectedAnswerCorrect = null;
    selectedAnswer = null;
    deactivateHeadTilt();
    notifyListeners();
  }

  // Restarts the quiz with shuffled questions.
  void restartQuiz() {
    currentQuestionIndex = 0; // Reset the current question index
    score = 0; // Reset the score
    selectedAnswer = null;
    selectedAnswerCorrect = null;
    isQuizFinished = false; // Reset the quiz completion status
    initializeQuizWithMockData(); // Re-initialize the quiz with mock data
    notifyListeners();
    activateHeadTilt();
  }

  // Since there is no backend connection, I am using a mock quiz

  // Initializes the quiz with a set of mock questions and shuffles them
  void initializeQuizWithMockData() {
    List<Question> mockQuestions = [
      Question(
        text: "What is the capital of France?",
        answers: [
          Answer(text: "Paris", isCorrect: true),
          Answer(text: "London", isCorrect: false),
          Answer(text: "Berlin", isCorrect: false),
          Answer(text: "Madrid", isCorrect: false),
        ],
      ),
      Question(
        text: "Which planet is known as the Red Planet?",
        answers: [
          Answer(text: "Earth", isCorrect: false),
          Answer(text: "Venus", isCorrect: false),
          Answer(text: "Mars", isCorrect: true),
          Answer(text: "Jupiter", isCorrect: false),
        ],
      ),
      Question(
        text: "In which year did the Titanic sink?",
        answers: [
          Answer(text: "1905", isCorrect: false),
          Answer(text: "1918", isCorrect: false),
          Answer(text: "1923", isCorrect: false),
          Answer(text: "1912", isCorrect: true),
        ],
      ),
      Question(
        text: "What is the largest country in the world?",
        answers: [
          Answer(text: "Canada", isCorrect: false),
          Answer(text: "Russia", isCorrect: true),
          Answer(text: "China", isCorrect: false),
          Answer(text: "United States", isCorrect: false),
        ],
      ),
      Question(
        text: "What is the chemical symbol for Gold?",
        answers: [
          Answer(text: "Ag", isCorrect: false),
          Answer(text: "Fe", isCorrect: false),
          Answer(text: "Cu", isCorrect: false),
          Answer(text: "Au", isCorrect: true),
        ],
      ),
      Question(
        text: "What is the largest mammal in the world?",
        answers: [
          Answer(text: "African Elephant", isCorrect: false),
          Answer(text: "Blue Whale", isCorrect: true),
          Answer(text: "Giraffe", isCorrect: false),
          Answer(text: "Grizzly Bear", isCorrect: false),
        ],
      ),
      Question(
        text: "What is the square root of 361",
        answers: [
          Answer(text: "19", isCorrect: true),
          Answer(text: "17", isCorrect: false),
          Answer(text: "18", isCorrect: false),
          Answer(text: "21", isCorrect: false),
        ],
      ),
      Question(
        text: "Where would you be, if you were standing on the Spanish Steps?",
        answers: [
          Answer(text: "Barcelona", isCorrect: false),
          Answer(text: "Madrid", isCorrect: false),
          Answer(text: "Rome", isCorrect: true),
          Answer(text: "Venice", isCorrect: false),
        ],
      ),
      Question(
        text: "Aurelion is a tone of which color?",
        answers: [
          Answer(text: "Blue", isCorrect: false),
          Answer(text: "Green", isCorrect: false),
          Answer(text: "Yellow", isCorrect: true),
          Answer(text: "Red", isCorrect: false),
        ],
      ),
      Question(
        text: "Which country has the hightest consume of coffee per capita?",
        answers: [
          Answer(text: "Sweden", isCorrect: false),
          Answer(text: "Finland", isCorrect: true),
          Answer(text: "Norway", isCorrect: false),
          Answer(text: "Denmark", isCorrect: false),
        ],
      ),
      Question(
        text: "Until 1923, what was the Turkish city of Istanbul called?",
        answers: [
          Answer(text: "Smyrna", isCorrect: false),
          Answer(text: "Ankara", isCorrect: false),
          Answer(text: "Izmir", isCorrect: false),
          Answer(text: "Constantinople", isCorrect: true),
        ],
      ),
      Question(
        text: "Name the longest river in the world?",
        answers: [
          Answer(text: "Amazon", isCorrect: false),
          Answer(text: "Nile", isCorrect: true),
          Answer(text: "Yangtze", isCorrect: false),
          Answer(text: "Mississippi", isCorrect: false),
        ],
      ),
      Question(
        text: "How many keys does a classic piano have?",
        answers: [
          Answer(text: "88", isCorrect: true),
          Answer(text: "86", isCorrect: false),
          Answer(text: "90", isCorrect: false),
          Answer(text: "92", isCorrect: false),
        ],
      ),
    ];

    // Shuffle the questions using Dart shuffle method
    mockQuestions.shuffle(); // leads to the quiz being not so boring

    // Initialize the quiz with the shuffled questions
    quiz = Quiz(questions: mockQuestions);
    notifyListeners();
  }
}
