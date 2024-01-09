import 'utility.dart';

// class to hold the data needed for a session
class Session {
  Setup? setup;
  double score = 0;
  double currentTemperature = 0;
  double notMovedFor = 0;
  double estimatedStartPhase = 0;
  Session(this.estimatedStartPhase, this.setup);
}
