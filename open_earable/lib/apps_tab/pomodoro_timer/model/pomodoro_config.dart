/// PomodoroConfig is a class that holds the configuration for the Pomodoro timer.
/// It contains the work and break minutes and the amount of repetitions.
class PomodoroConfig{
  int _workMinutes = 20;
  int _breakMinutes = 5;
  int _repetitions = 0;

  PomodoroConfig();

  set breakMinutes(int minutes) {
    if (minutes < 1) throw ArgumentError('Break minutes must be at least 1');

    _breakMinutes = minutes;
  }

  set workMinutes(int minutes) {
    if (minutes < 1) throw ArgumentError('Work minutes must be at least 1');
    _workMinutes = minutes;
  }

  set repetitions(int repetitions) {
    _repetitions = repetitions;
  }

  

  int get workMinutes => _workMinutes;
  int get breakMinutes => _breakMinutes;

  int get repetitions => _repetitions;
}
