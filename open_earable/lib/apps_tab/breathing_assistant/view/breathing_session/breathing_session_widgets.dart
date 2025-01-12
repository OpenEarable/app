import 'package:flutter/material.dart';
import 'circular_progress_painter.dart';

/// A widget to display posture feedback during the breathing session.
///
/// - If night mode is enabled, it displays plain text feedback.
/// - Otherwise, it shows a styled container with posture feedback.
class PostureFeedbackWidget extends StatelessWidget {
  /// Whether night mode is enabled.
  final bool isNightMode;

  /// The feedback text to display.
  final String feedback;

  /// Creates a [PostureFeedbackWidget] with the specified properties.
  const PostureFeedbackWidget({
    required this.isNightMode,
    required this.feedback,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isNightMode
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              feedback.isEmpty
                  ? "Waiting for posture feedback..."
                  : feedback,
              style: TextStyle(
                fontSize: 18,
                color: feedback.contains("Correct")
                    ? const Color.fromARGB(255, 62, 141, 63)
                    : const Color.fromARGB(255, 189, 140, 48),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          )
        : Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(212, 255, 255, 255).withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              feedback.isEmpty
                  ? "Waiting for posture feedback..."
                  : feedback,
              style: TextStyle(
                fontSize: 18,
                color: feedback.contains("Correct")
                    ? const Color.fromARGB(255, 71, 156, 72)
                    : const Color.fromARGB(255, 15, 82, 159),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          );
  }
}

/// A widget to display a countdown before the breathing session starts.
class CountdownWidget extends StatelessWidget {
  final int countdown;

  /// Creates a [CountdownWidget] with the specified countdown value.
  const CountdownWidget({required this.countdown, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey("countdown"),
      child: Text(
        countdown.toString(),
        style: const TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// A widget to display the session completion screen.
class CompletionWidget extends StatelessWidget {
  final VoidCallback onGoBack;

  /// Creates a [CompletionWidget] with the specified callback.
  const CompletionWidget({required this.onGoBack, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey("completion"),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 100),
          const SizedBox(height: 20),
          const Text(
            "Exercise Completed!",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onGoBack,
            child: const Text("Go Back"),
          ),
        ],
      ),
    );
  }
}

/// A widget to manage and display the breathing session animation and progress.
class BreathingWidget extends StatelessWidget {
  /// Animation for breathing progress (circular progress bar).
  final Animation<double> progressAnimation;

  /// Animation for the size of the breathing circle.
  final Animation<double> sizeAnimation;

  /// The current breathing phase (e.g., "Inhale", "Hold", "Exhale").
  final String currentPhase;

  /// Whether night mode is enabled.
  final bool isNightMode;

  /// Callback to execute when the "End Session" button is pressed.
  final VoidCallback onEndSession;

  /// Creates a [BreathingWidget] with the specified animations and properties.
  const BreathingWidget({
    required this.progressAnimation,
    required this.sizeAnimation,
    required this.currentPhase,
    required this.isNightMode,
    required this.onEndSession,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Circular progress bar for breathing animation.
        Positioned.fill(
          child: Align(
            alignment: MediaQuery.of(context).orientation == Orientation.landscape
                ? Alignment.topCenter
                : Alignment.center,
            child: AnimatedBuilder(
              animation: Listenable.merge([progressAnimation, sizeAnimation]),
              builder: (context, child) {
                return CustomPaint(
                  painter: CircularProgressPainter(
                    progressAnimation.value,
                    currentPhase,
                  ),
                  size: Size(sizeAnimation.value, sizeAnimation.value),
                );
              },
            ),
          ),
        ),

        // End Session button positioned dynamically based on orientation.
        Positioned(
          bottom: MediaQuery.of(context).orientation == Orientation.landscape ? 30 : 50,
          left: 20,
          right: 20,
          child: ElevatedButton(
            onPressed: onEndSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: isNightMode
                  ? const Color.fromARGB(255, 33, 33, 33)
                  : const Color.fromARGB(255, 50, 50, 50),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "End Session",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
