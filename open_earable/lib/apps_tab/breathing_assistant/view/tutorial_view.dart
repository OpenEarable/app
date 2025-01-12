import 'package:flutter/material.dart';

/// A [HowToUseScreen] widget that provides detailed instructions and information
/// about the app's features and functionality.
///
/// ### Features:
/// - Step-by-step guide on practicing the 4-7-8 breathing technique.
/// - Understanding posture feedback colors.
/// - Information about the app's purpose and benefits.
///
/// This screen adapts to portrait/landscape orientation.
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Detect if the app is in dark mode.
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Detect if the device is in landscape orientation.
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text("How to Use?"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 38, 38, 38),
              Color.fromARGB(255, 70, 78, 88),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment:
                  isLandscape ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                // Card: Guide to 4-7-8 breathing technique.
                _buildCard(
                  title: "How to Practice 4-7-8 Breathing?",
                  content: [
                    "Find a quiet and comfortable place to sit or lie down on your back.",
                    "Before starting, you can set the exercise duration and choose between light or dark mode in the settings.",
                    "Click on 'Start Breathing Exercise'.",
                    "Choose if you will do the breathing exercise sitting or lying down.",
                    "A countdown will appear, starting from 3 to prepare you for the session.",
                    "Breathe in deeply through your nose for four counts as the progress bar fills on the screen.",
                    "Hold your breath for seven counts while the progress bar continues.",
                    "Exhale slowly through your mouth for eight counts, following the progress bar.",
                    "Repeat the cycle for the duration of your session.",
                  ],
                  isDarkMode: isDarkMode,
                  isNumbered: true,
                ),
                const SizedBox(height: 20),

                // Card: Explanation of feedback colors.
                _buildCard(
                  title: "Understanding Feedback Colors",
                  content: [
                    "Green: Your posture is correct! Keep going.",
                    "Red/Yellow: Your posture needs adjustment. For example:",
                    "- Leaning too far forward or backward.",
                    "- Tilting your shoulders to the left or right.",
                  ],
                  isDarkMode: isDarkMode,
                  highlightColors: {
                    "Green": const Color.fromARGB(255, 62, 141, 63),
                    "Red": const Color.fromARGB(255, 188, 57, 47),
                    "Yellow": const Color.fromARGB(255, 189, 140, 48),
                  },
                ),
                const SizedBox(height: 20),

                // Card: Why the app exists.
                _buildCard(
                  title: "Why this App?",
                  content: [
                    "Did you know that over 35% of adults globally struggle with sleep issues, such as insomnia or difficulty falling asleep?",
                    "This app is designed to help users reduce anxiety, improve relaxation, and promote better sleep using the 4-7-8 breathing technique.",
                    "You can choose the session duration, with the default set to 4 minutes.",
                  ],
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 20),

                // Card: Benefits of using the app.
                _buildCard(
                  title: "What are the Benefits?",
                  content: [
                    "Calms the nervous system and reduces stress.",
                    "Helps you fall asleep faster and improves sleep quality.",
                    "Promotes mindfulness and relaxation.",
                    "Enhances lung capacity and oxygen intake.",
                  ],
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 30),

                // Closing message with a motivational note.
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 70, 169, 249),
                          Color.fromARGB(255, 115, 207, 250),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      "Relax, breathe, and enjoy your journey to better sleep!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a styled card with a title and content list.
  ///
  /// [title]: The title displayed at the top of the card.
  /// [content]: A list of strings to be displayed inside the card.
  /// [isDarkMode]: Whether the app is in dark mode.
  /// [isNumbered]: Whether the content list is numbered (default: false).
  /// [highlightColors]: Map of words to highlight with specific colors.
  Widget _buildCard({
    required String title,
    required List<String> content,
    required bool isDarkMode,
    bool isNumbered = false,
    Map<String, Color>? highlightColors,
  }) {
    return Card(
      color: const Color.fromARGB(255, 30, 34, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final text = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNumbered)
                        Text(
                          "$index. ",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8FBFE0),
                          ),
                        )
                      else
                        const Icon(
                          Icons.circle,
                          size: 8,
                          color: Color(0xFF8FBFE0),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                            ),
                            children: _buildTextSpans(text, highlightColors, isDarkMode),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Splits content into text spans, highlighting specific words.
  ///
  /// [content]: The string to be processed.
  /// [highlightColors]: Map of words to highlight with their respective colors.
  /// [isDarkMode]: Whether the app is in dark mode.
  List<TextSpan> _buildTextSpans(
      String content, Map<String, Color>? highlightColors, bool isDarkMode,) {
    final textSpans = <TextSpan>[];

    final regex = RegExp(highlightColors?.keys.join('|') ?? "");
    content.splitMapJoin(
      regex,
      onMatch: (match) {
        final color = highlightColors?[match[0]] ?? Colors.white;
        textSpans.add(
          TextSpan(
            text: match[0],
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        return "";
      },
      onNonMatch: (text) {
        textSpans.add(
          TextSpan(
            text: text,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        );
        return "";
      },
    );

    return textSpans;
  }
}
