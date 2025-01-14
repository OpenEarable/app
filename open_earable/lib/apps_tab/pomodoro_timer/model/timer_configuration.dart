import 'package:open_earable/apps_tab/pomodoro_timer/model/time_units.dart';

/// This class represents the configuration of a timer
/// with hours, minutes and seconds.
class TimerConfiguration {
  int _seconds = 0;
  int _minutes = 0;
  int _hours = 0;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// toggle the running state to true
  void run() {
    _isRunning = true;
  }

  /// toggle the running state to false
  void stop() {
    _isRunning = false;
  }


  /// Konstruktor zur Initialisierung von Stunden und Minuten.
  TimerConfiguration(int hours, int minutes) {
    //_hours = hours;
    //_minutes = minutes;
    hours = hours;
    _minutes = minutes;
  }

  /// Placeholder-Konstruktor mit Standardwerten.
  TimerConfiguration.placeholder();

  /// Getter für verbleibende Sekunden, Minuten und Stunden als Map.
  Map<TimeUnits, int> get timeLeftHMS {
    return {
      TimeUnits.seconds: _seconds,
      TimeUnits.minutes: _minutes,
      TimeUnits.hours: _hours,
    };
  }

  /// Getter für verbleibende Sekunden.
  int get seconds => _seconds;

  /// Setter für Sekunden, der Minuten und Stunden bei Überläufen anpasst.
  set seconds(int value) {
    _seconds = value;
  }

  /// Getter für verbleibende Minuten.
  int get minutes => _minutes;

  /// Setter für Minuten, der Stunden bei Überläufen anpasst.
  set minutes(int value) {
    _minutes = value;
  }

  /// Getter für verbleibende Stunden.
  int get hours => _hours;

  /// Setter für Stunden.
  set hours(int value) {
    if (value >= 0) {
      _hours = value;
    } else {
      throw ArgumentError("Stunden dürfen nicht negativ sein.");
    }
  }

  /// Getter für die gesamte verbleibende Zeit in Sekunden.
  int get allSecondsLeft => _seconds + 60 * (_minutes + 60 * _hours);

  /// Getter für die gesamte verbleibende Zeit in Minuten.
  int get allMinutesLeft => _minutes + 60 * _hours;

  /// Methode zum Verringern der Minuten.
  void decreaseMinutes(int amount) {
    if (amount >= 0) {
      int totalMinutes = allMinutesLeft - amount;
      hours = totalMinutes ~/ 60;
      minutes = totalMinutes % 60;
    } else {
      throw ArgumentError("Reduktion darf nicht negativ sein.");
    }
  }

  /// Methode zum Verringern der Sekunden.
  void decreaseSeconds(int amount) {
    if (amount >= 0) {
      int totalSeconds = allSecondsLeft - amount;
      hours = totalSeconds ~/ 3600;
      minutes = (totalSeconds ~/ 60) % 60;
      seconds = totalSeconds % 60;
    } else {
      throw ArgumentError("Reduktion darf nicht negativ sein.");
    }
  }

  /// Methode zum Verringern der Stunden.
  void decreaseHours(int amount) {
    if (amount >= 0) {
      int totalHours = _hours - amount;
      hours = totalHours < 0 ? 0 : totalHours;
    } else {
      throw ArgumentError("Reduktion darf nicht negativ sein.");
    }
  }
}
