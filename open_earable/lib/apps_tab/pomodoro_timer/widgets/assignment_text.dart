import 'package:flutter/cupertino.dart';

/// A widget that displays the assignment text.
/// The text is displayed in a container with a border and rounded corners.
/// The font size is increased.
/// The text is centered.
/// The text is padded.
/// This should be used, to keep the text consistent.
class AssignmentText extends StatelessWidget {
  final String text;
  const AssignmentText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: CupertinoColors.white),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18, // Increase the font size
            ),
          ),
        ),
      ),
    );
  }
}
