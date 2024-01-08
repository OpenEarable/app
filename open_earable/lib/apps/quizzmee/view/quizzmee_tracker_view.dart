import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/quizzmee/view_model/quizzmee_tracker_view_model.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:provider/provider.dart';

import '../model/answer.dart';

// StatefulWidget that handles the UI and user interaction
class QuizzmeeView extends StatefulWidget {
  final OpenEarable _openEarable;
  final QuizzmeeViewModel _viewModel = QuizzmeeViewModel();

  QuizzmeeView(this._openEarable);

  @override
  _QuizzmeeViewState createState() => _QuizzmeeViewState();
}

// State class for QuizzmeeView.
class _QuizzmeeViewState extends State<QuizzmeeView> {
  bool quizStarted = false;
  late final QuizzmeeViewModel _viewModel;
  // Subscription to listen to sensor data from the earable device
  late StreamSubscription<Map<String, dynamic>> sensorSubscription;

  // Define tilt thresholds in radians for head movements
  /* note: Since i've been given an earable device for the left ear, the
  thresholds are not really symmetric, because the device is not perfectly
  centered on the head.
  If one is using a device for both ears or for the right ear,
  the thresholds would have to be adjusted.

  Numbers for the left ear, that worked well for me are:
  final double rightTiltThreshold = 20 * (pi / 180);
  final double leftTiltThreshold = -35 * (pi / 180);
  final double backwardTiltThreshold = -15 * (pi / 180);
  final double forwardTiltThreshold = 25 * (pi / 180);
   */

  // Guessed symmetrical thresholds (see explanation above)
  final double rightTiltThreshold = 30 * (pi / 180);
  final double leftTiltThreshold = -30 * (pi / 180); // Negative for left tilt
  final double backwardTiltThreshold =
      -20 * (pi / 180); // Negative for backward tilt
  final double forwardTiltThreshold = 25 * (pi / 180);

  @override
  void initState() {
    super.initState();
    _viewModel = widget._viewModel;
    subscribeToSensorData();
  }

  // Subscribes to sensor data and listens for head movements
  void subscribeToSensorData() {
    var sensorConfig =
        OpenEarableSensorConfig(sensorId: 0, samplingRate: 30.0, latency: 0);
    widget._openEarable.sensorManager.writeSensorConfig(sensorConfig);
    sensorSubscription = widget._openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen(handleSensorData);
  }

  // Handles sensor data to detect head movements and select answers
  void handleSensorData(Map<String, dynamic> data) {
    if (_viewModel.isHeadTiltActive == false)
      return; // Ignore head tilts if selection is deactivated

    var roll = data["EULER"]["ROLL"];
    var pitch = data["EULER"]["PITCH"];

    // Check against thresholds and select appropriate answer
    if (roll > rightTiltThreshold) {
      selectAnswerByIndex(2); // Select right answer
    } else if (roll < leftTiltThreshold) {
      selectAnswerByIndex(1); // Select left answer
    } else if (pitch > forwardTiltThreshold) {
      selectAnswerByIndex(3); // Select bottom answer
    } else if (pitch < backwardTiltThreshold) {
      selectAnswerByIndex(0); // Select top answer
    }
  }

  // Selects an answer based on the index of the answer in the quiz list
  void selectAnswerByIndex(int index) {
    if (_viewModel.currentQuestion.answers.length > index) {
      _viewModel
          .handleAnswerSelection(_viewModel.currentQuestion.answers[index]);
    }
  }

  @override
  void dispose() {
    sensorSubscription.cancel();
    super.dispose();
  }

  // Builds the UI of the app
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Quizzmee")),
      body: ChangeNotifierProvider<QuizzmeeViewModel>.value(
        value: widget._viewModel,
        builder: (context, child) => Consumer<QuizzmeeViewModel>(
          builder: (context, viewModel, child) {
            return quizStarted ? _buildQuizContent() : _buildStartScreen();
          },
        ),
      ),
      backgroundColor: Colors.blue,
    );
  }

  // Builds the start screen of the quiz
  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz,
            size: 100,
            color: Colors.white,
          ),
          SizedBox(height: 25),
          Text(
            "Welcome to Quizzmee!",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 25),
          Text(
            "Press the button below to start the quiz.",
            style: TextStyle(fontSize: 22, color: Colors.white),
          ),
          SizedBox(height: 25),
          ElevatedButton(
            onPressed: () => setState(() {
              print("Start-Button pressed");
              quizStarted = true;
              _viewModel.activateHeadTilt();
            }),
            child: Text("Start Quiz", style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  // Builds the main content of the quiz either as a question or the result
  Widget _buildQuizContent() {
    if (_viewModel.isQuizFinished) {
      return _buildResultsScreen();
    } else {
      return _buildQuizQuestionView();
    }
  }

  // Builds the view for a quiz question
  Widget _buildQuizQuestionView() {
    var question = _viewModel.currentQuestion;
    return Column(
      mainAxisAlignment:
          MainAxisAlignment.start, // Aligns children to the start of the column
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          margin: EdgeInsets.all(16.0),
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary, // Background color of the box
            borderRadius: BorderRadius.circular(10), // Rounded corners
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary,
                spreadRadius: 2,
                blurRadius: 4,
                offset: Offset(0, 3), // changes position of shadow
              ),
            ],
          ),
          child: Text(
            question.text,
            style: TextStyle(fontSize: 24, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 20),
        _buildAnswerOptions(question.answers),
      ],
    );
  }

  // Builds the options for answers
  Widget _buildAnswerOptions(List<Answer> answers) {
    return Expanded(
      // Use Expanded to fill the available space
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center, // Center the column's children
        children: <Widget>[
          _answerCard(answers[0]), // Top card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _answerCard(answers[1]), // Left center card
              _answerCard(answers[2]), // Right center card
            ],
          ),
          _answerCard(answers[3]), // Bottom card
        ],
      ),
    );
  }

  // Builds the individual answer card
  Widget _answerCard(Answer answer) {
    Color cardColor = Theme.of(context).colorScheme.primary;
    // Check if any answer has been selected
    if (_viewModel.selectedAnswer != null) {
      if (answer.isCorrect) {
        cardColor = Colors.green;
      } else if (_viewModel.selectedAnswer == answer &&
          !_viewModel.selectedAnswerCorrect!) {
        cardColor = Colors.red;
      }
    }

    // Define a fixed size for the cards
    final double cardWidth = MediaQuery.of(context).size.width / 2 - 20;
    final double cardHeight = MediaQuery.of(context).size.width / 4;

    return Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor, // Background color of the button
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary, // Shadow color
                spreadRadius: 2,
                blurRadius: 4,
                offset: Offset(0, 3), // changes position of shadow
              ),
            ],
          ),
          child: SizedBox(
            // Use SizedBox to constrain size
            width: cardWidth,
            height: cardHeight,
            child: Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ElevatedButton(
                onPressed: () {
                  if (_viewModel.selectedAnswerCorrect == null) {
                    _viewModel.handleAnswerSelection(answer);
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: cardColor,
                ),
                child: Text(
                  answer.text,
                  style: TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis, // Handle text overflow
                ),
              ),
            ),
          ),
        ));
  }

  // Builds the results screen shown after the quiz ends
  Widget _buildResultsScreen() {
    String message =
        _getCheerfulMessage(_viewModel.score, _viewModel.quiz.questions.length);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Quiz Completed!",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          SizedBox(height: 40),
          Text("Your Score: ${_viewModel.score}",
              style: TextStyle(fontSize: 24)),
          SizedBox(height: 25),
          Container(
            padding: EdgeInsets.all(16), // Padding inside the container
            margin: EdgeInsets.symmetric(
                horizontal: 20), // Margin around the container
            decoration: BoxDecoration(
              color: Colors.yellow.shade100, // Yellowish background
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 20,
                color: Colors.brown, // Custom text color
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 25),
          ElevatedButton(
            onPressed: () => _viewModel.restartQuiz(),
            child: Text("Restart Quiz", style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  // Generates a cheerful message based on the user's score
  String _getCheerfulMessage(int score, int totalQuestions) {
    if (score == totalQuestions) {
      return "Perfect score! Well done!";
    } else if (score > totalQuestions / 2) {
      return "You're quite knowledgeable!";
    } else {
      return "Good effort! Keep practicing!";
    }
  }
}
