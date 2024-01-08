/**
 * Score object, that's able to compare itself to other Scores
 */
class Score {
  late String scoreText;
  late double value = 0;
  final int maxScore;

  Score({required int score, required this.maxScore}) {
    scoreText = "$score/$maxScore";
    /// check for division by zero
    if (maxScore != 0) {
      value = (score.toDouble()) / (maxScore.toDouble());
    } else {
      value = 0;
    }
  }

  /**
   * Returns True when this Score is better or equal to the other Score
   * If they are equal, the one with the higher reachable score is better
   */
  bool isBetter(Score score) {
    if (value == score.value) return maxScore >= score.maxScore;
    return value > score.value;
  }
}
