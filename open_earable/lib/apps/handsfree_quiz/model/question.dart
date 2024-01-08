/**
 * Question Object it contains the Question and the Answer value and has a
 * textual representation, containing Question and Answer
 */
class Question {
  final String question;
  final bool answer;
  final String firstAnswer;
  final String secondAnswer;

  Question({required this.question, required this.firstAnswer, required this.secondAnswer, required this.answer});

  String answerText() {
    return answer ? firstAnswer : secondAnswer;
  }

  @override
  String toString() {
    return "$question     " + answerText();
  }
}
