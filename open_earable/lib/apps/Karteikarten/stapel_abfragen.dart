import 'package:flutter/material.dart';
import 'dart:async';
import 'package:open_earable/apps/posture_tracker/model/attitude.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';

class FrageAbfrage extends StatefulWidget {

  final List<Map<String, dynamic>> paare;
  final OpenEarable _openEarable;


  final Attitude _rawAttitude = Attitude();
  Attitude get rawAttitude => _rawAttitude;
  final AttitudeTracker _attitudeTracker;



  FrageAbfrage(this.paare,this._openEarable,this._attitudeTracker);

  @override
  _FrageAbfrageState createState() => _FrageAbfrageState(_openEarable, _attitudeTracker);
}

class _FrageAbfrageState extends State<FrageAbfrage> {
  // Instanzen für die Verfolgung von Bewegungen und für Funktionen bzgl. des Kopf bewegens.
  AttitudeTracker _attitudeTracker;
  final OpenEarable _openEarable;
  _FrageAbfrageState( this._openEarable, this._attitudeTracker);
  Attitude _attitude = Attitude();
  Attitude get attitude => _attitude;
  // Zustandsvariablen für das Tracking.
  bool get isTracking => _attitudeTracker.isTracking;
  bool get isAvailable => _attitudeTracker.isAvailable;
  double pitchMin = 0;
  double pitchMax = 0;
  double yawMin = 0;
  double yawMax = 0;
  int streak = 0;
  int negStreak = 0;

  var rng = Random();
  int currentIndex = 0;
  int nextIndex = 0;
  Timer? _timer;
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
//damit das Programm auch funktioniert falls kein Earable angeschlossen ist
    if (_openEarable.bleManager.connected) {
      _timer = Timer.periodic(Duration(milliseconds: 500), (Timer t) => adjustGyroValues());
      _attitudeTracker.start();
    }
    currentIndex = rng.nextInt(widget.paare.length); // Erzeugt eine Zahl von 0 bis anzahl paare -1

  }
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }//tts funktioniert mit nativen Lautsprechern oder anderen Kopfhörern
  void _initTts() {
    flutterTts.setLanguage("de-DE");
  }
  //Funktion zum überprüfen ob die Antwort auf die Frage richtig war
  void _ueberpruefeAntwort(bool antwort) {
    //zurücksetzen der pitch und yaw Werte für die  nächste Frage
    pitchMax = 0;
    pitchMin = 0;
    yawMax = 0;
    yawMin = 0;
    //falls die bool Werte übereinstimmen ist es richtig beantwortet
    if (widget.paare[currentIndex]['wert'] == antwort) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Glückwunsch!'),
            duration: Duration(seconds: 1),
          )
      );
      _openEarable.audioPlayer.jingle(
          2); //abspielen einer jingle zum anzeigen des richtigen Antwortens
      streak++;
      negStreak =
      0; // Bei 5..10..15..etc richtig beantworteten Fragen in Folge gibt es eine kleine extrabelohnung
      if (streak % 5 == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Sie haben bereits ${streak} in Folge richtig beantwortet'),
              duration: Duration(seconds: 3),
            )
        );
      }
//falls die bools nicht übereinstimmen wurde die Frage falsch beantwortet
    } else {
      streak = 0;
      negStreak--;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leider Falsch!'),
            duration: Duration(seconds: 1),
          )
      );
      _openEarable.audioPlayer.jingle(3);
      // kleine Tipps falls viele Fragen in Folge falsch beantwortet wurden
      if (negStreak == -5) {
        negStreak == 0;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Falls sie Probleme mit dem automatischen erkennen ihrer Kopfbewegungen haben versuchen sie ihren Kopf zwischen den Fragen nicht zu viel zu bewegen und versuchen sie die Fragen nicht zu lesen sonder mithilfe von TtS zu hören'),
              duration: Duration(seconds: 5),
            )
        );
      }
    }
    _nextQuestion();

  }
//Da der durschnittliche Stapel relativ groß ist sollten Wiederholungen nicht allzu oft vorkommen
void _nextQuestion(){
  //eine zuällige nächste Frage wird ausgesucht die ungleich der jetzigen ist falls es nur eine Frage gibt wird dies übersprungen
  if (!(widget.paare.length == 1)) {
    setState(() {
      do {
        nextIndex = rng.nextInt(widget.paare.length); // Erzeugt eine zufällige Zahl von 0 bis anzahl paare -1
      } while (nextIndex == currentIndex); //falls die erzeugte Zahl die alte Zahl war war wird nochmal eine erzeugt
      currentIndex = nextIndex;
    });
  }
  //pausiert kurz die ermittlung der Earable Position um zu vermeiden dass eine Restbewegung für die nächste Frage interpretiert wird
  if (_openEarable.bleManager.connected) {
    pauseTimerTemporarily();
  }
}
//TtS um das bediehnen ohne auf das Handy schauen zu ermöglichen
  void _speakQuestion() async {
    if (widget.paare.isNotEmpty) {
      String currentQuestion = widget.paare[currentIndex]['satz'];
      await flutterTts.speak(currentQuestion);
    }
  }
  //wird regelmäßig aufgerufen um die aktuelle Position des Earables zu ermittlen
  void adjustGyroValues() {
    _attitudeTracker.listen((attitude) {
      _attitude = Attitude(
          roll: attitude.roll,
          pitch: attitude.pitch,
          yaw: attitude.yaw
      );
    });
    //falls pitchMin == 0 wird davon ausgegangen dass es noch nicht gemessen wurde und es wird initalisiert
    if (pitchMin == 0){
      pitchMin = attitude.pitch;
      pitchMax = attitude.pitch;
      //falls yawMin == 0 wird davon ausgegangen dass es noch nicht gemessen wurde und es wird initalisiert

    }
    if (yawMin == 0){
      yawMin = attitude.yaw;
      yawMax = attitude.yaw;

    }
    //Es werden pitchMin,pitchMax,yawMin,yawMax aktuallisiert falls die neuen Werte größer/Kleiner als die alten sind
    if (attitude.pitch < pitchMin ) {
      pitchMin = attitude.pitch;
    }
    if (attitude.pitch > pitchMax) {
      pitchMax = attitude.pitch;
    }

    if (yawMin == 0){
      yawMin = attitude.pitch;
      yawMax = attitude.pitch;

    }
    if (attitude.yaw < yawMin) {

      yawMin = attitude.yaw;
    }
    if (attitude.yaw > yawMax) {
      yawMax = attitude.yaw;
    }
    //In der Übung wurde gesagt wir sollen mit schwellenwerten arbeiten und diese Werte haben am besten für mich funktioniert
    if (((pitchMax - pitchMin).abs()) >= 0.75){
      _ueberpruefeAntwort(true);

    }
    else if (((yawMax - yawMin).abs()) >= 0.18){
      _ueberpruefeAntwort(false);


    }
  }
  //stopt den Timer der regelmäßig adjustGyroValues aufruft
  void stopTimer() {
    _timer?.cancel();
  }
  //startet den Timer wieder
  void startTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 500), (Timer t) => adjustGyroValues());
  }
  //pausiert nach dem beantworten einer Frage für eine Sekunde um das zurücksetzen der Kopfposition zu ermöglichen
  void pauseTimerTemporarily() {
    stopTimer();
    Future.delayed(Duration(milliseconds: 1000), startTimer);
  }
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakQuestion());
    return Scaffold(
      appBar: AppBar(title: Text('Karteikarten abfragen')),
      body: widget.paare.isEmpty
          ? Center(child: Text('Keine Fragen verfügbar'))
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          //aktuelle Frage wird angezeigt
          Text(widget.paare[currentIndex]['satz'], style: TextStyle(fontSize: 24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              //auswählen per hand ob frage Wahr oder Falsch ist
              ElevatedButton(
                onPressed: () => _ueberpruefeAntwort(true),
                child: Text('Wahr'),
              ),
              ElevatedButton(
                onPressed: () => _ueberpruefeAntwort(false),
                child: Text('Falsch'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}