/// This class saves the settings for the Pomodoro Timer App
class PomodoroAppSettings {
  /// The default amount of repetitions for the nod exercise.
  int _nodExerciseDefaultRepetitionAmount = 10;

  int get nodExerciseDefaultRepetitions => _nodExerciseDefaultRepetitionAmount;

  set nodExerciseDefaultRepetitions(int repetitions) {
    _nodExerciseDefaultRepetitionAmount = repetitions;
  }
}
