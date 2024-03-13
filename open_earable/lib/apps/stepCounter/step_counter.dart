import 'package:flutter/material.dart';
import 'package:open_earable/widgets/earable_not_connected_warning.dart';
import 'dart:async';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/**
 * Erstellt einen naiven Schrittzähler, dieser basiert auf dem erreichen eines Schwellenwerts in der Summe der Beschleunigungswerte (x,y,z).
 * Es wird auch die Durchschnittliche Geschwindigkeit in Schritte pro Sekunde berechnet.
 */
class StepCounter extends StatefulWidget {
  final OpenEarable _openEarable;

  TextEditingController stoppedTimeController = TextEditingController();
  TextEditingController countedStepsController = TextEditingController();

  StepCounter(this._openEarable);

  @override
  _StepCounterState createState() => _StepCounterState(_openEarable);
}

/**
 * Definiert den den Schrittzähler und den Timer
 */
class _StepCounterState extends State<StepCounter> {
  final OpenEarable _openEarable;

  _StepCounterState(this._openEarable);

  Duration _duration = Duration();
  bool _startStepCount = false;
  StreamSubscription? _imuSubscription;
  Timer? _timer;
  int _countedSteps = 0;

  /**
   * Aktualisiert die aus der Einstellungsseite erhaltenen Werte
   */
  void updateValues(String stoppedTime, String countedSteps) {
    print(
        'Received values: stoppedTime=$stoppedTime, countedSteps=$countedSteps');
    setState(() {
      _duration = stringToDuration(stoppedTime);
      _countedSteps = int.parse(countedSteps);
    });
    print('Updated values: _duration=$_duration, _countedSteps=$_countedSteps');
  }

  /**
   * Wandelt den eingegebenen String in eine Uhrzeit um.
   * Es werden Folgende Formate unterstützt:
   * HH:MM:SS
   * MM:SS
   * SS (wird in Duration der Form HH:MM:SS umgewandelt)
   *
   */
  Duration stringToDuration(String stoppedTime) {
    List<String> timeComponents = stoppedTime.split(':');
    if (timeComponents.length == 3) {
      int hours = int.parse(timeComponents[0]);
      int minutes = int.parse(timeComponents[1]);
      int seconds = int.parse(timeComponents[2]);

      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    } else if (timeComponents.length == 2) {
      int minutes = int.parse(timeComponents[0]);
      int seconds = int.parse(timeComponents[1]);
      return Duration(hours: 0, minutes: minutes, seconds: seconds);
    } else if (timeComponents.length == 1) {
      return Duration(seconds: int.parse(timeComponents[0]));
    } else {
      return Duration(hours: 0, minutes: 0, seconds: 0);
    }
  }

  /**
   * Bei Aufruf wird das Schrittzählen gestartet, falls dieses bereits läuft wird es gestoppt
   */
  void startStopStepCount() async {
    if (_startStepCount) {
      setState(() {
        _startStepCount = false;
      });
      _stopTimer();
    } else {
      _startTimer();
      setState(() {
        _startStepCount = true;
      });
    }
  }

  /**
   * Formatiert eine Zeitangabe in einen klassischen Uhrzeitstring HH:MM:SS
   */
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  /**
   * Berechnet die durchschnittlichen Schritte pro Minute
   */
  String _formatAvgCadence(int steps, Duration duration) {
    if (duration.inSeconds != 0) {
      return (60.0 * steps / duration.inSeconds.toDouble()).toStringAsFixed(2);
    }
    return ""; // Wenn durch 0 geteilt wird
  }

  /**
   * Setzt den Schrittzähler zurück, falls gerade keine Schritte gezählt werden
   */
  void _resetStepCount() {
    if (_startStepCount) {
      return;
    }
    setState(() {
      _countedSteps = 0;
      _duration = Duration.zero;
    });
  }

  /**
   * Setzt den Timer auf 00:00:00 zurück und erstellt einen fotlaufenden Timer
   */
  void _startTimer() {
    _duration = Duration();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _duration = _duration + Duration(seconds: 1);
      });
    });
  }

  /**
   * Hält den Timer an
   */
  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
  }

  /**
   * Ruft die Sensordaten vom Earable ab und verarbeitet dies.
   */
  _setupListeners() {
    OpenEarableSensorConfig config =
        OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
    _openEarable.sensorManager.writeSensorConfig(config);
    _imuSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      if (!_startStepCount) {
        return;
      }
      // dynamic timestamp = data["timestamp"];

      double ax = data["ACC"]["X"] as double;
      double ay = data["ACC"]["Y"] as double;
      double az = data["ACC"]["Z"] as double;

      List<int> sensorData = [ax.toInt(), ay.toInt(), az.toInt()];

      _countedSteps = countSteps(sensorData);
    });
  }

  int countSteps(List<int> data) {
    final int numTuples = data.length ~/ 3;
    final int stepThreshold =
        238; // Dieser Schwellenwert wurde mit dem zur Verfügung gestellten Earable getestet,
    // ob dieser Wert für alle Earable funktioniert kann nicht gewährleistet werden.

    int numSteps = _countedSteps;

    // Schleife über die Sensordaten
    for (int i = 0; i < numTuples; i++) {
      // Berechne die Beschleunigung
      int tempMag = data[i * 3] * data[i * 3] +
          data[i * 3 + 1] * data[i * 3 + 1] +
          data[i * 3 + 2] * data[i * 3 + 2];

      // Wenn die Beschleunigung den Schwellenwert überschreitet wird ein Schritt gezählt.
      if (tempMag > stepThreshold) {
        numSteps++;
      }
    }

    return numSteps;
  }

  /**
   * Inizialisiert den Schrittzähler bzw. fügt ihn dem Baum hinzu.
   */
  @override
  void initState() {
    super.initState();
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
  }

  /**
   * Entfernt den Schrittzähler vom Baum.
   */
  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _imuSubscription?.cancel();
  }

  /**
   * Stellt die GUI zur Verfügung, Hier werden auch die Informationen von der Einstellungsseite abgerufen.
   */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('StepCounter'),
      ),
      // Beschränkt die GUI auf nicht von Betriebssystem verwendeten Bereich. Funktioniert nicht auf jedem Gerät.
      body: SafeArea(
        child: _openEarable.bleManager.connected
            ? _StepCounterWidget()
            : _StepCounterWidget(),
        // Hier Könnte eine Fehlermeldung eingefügt werden, weil das Earable nicht verbunden ist.
        // Die App ist aber auch teilweise zur Berchnung der Pro Sekunde zurückgelegten Schritte verwendbar.
        // Deshalb wird keine Fehlermeldung auf dem ganzen Bildschrirm ausgegeben.
      ),
    );
  }

  /**
   * Dieses Widget stellt sicher das das Gerät bei verwendung der App gedreht werden kann.
   */
  Widget _StepCounterWidget() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = constraints.maxWidth;

          return screenWidth > 600 ? _buildRow() : _buildColumn();
        },
      ),
    );
  }

  /**
   * Erstellt die GUI im Landscape Modus
   */
  Widget _buildRow() {
    return !_openEarable.bleManager.connected
        ? EarableNotConnectedWarning()
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildListTile(
                        _formatDuration(_duration), "Stopped Time", 40),
                    _buildListTile(
                        _countedSteps.toString(), "Counted Steps", 40),
                    _buildListTile(_formatAvgCadence(_countedSteps, _duration),
                        "Avg. Cadence\n(Steps per Minute)", 40),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButtons(),
                  ],
                ),
              ),
            ],
          );
  }

  /**
   * Erstellt die GUI im Portait Modus
   */
  Widget _buildColumn() {
    return !_openEarable.bleManager.connected
        ? EarableNotConnectedWarning()
        : Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Spacer(),
              _buildListTile(_formatDuration(_duration), "Stopped Time", 45),
              _buildListTile(_countedSteps.toString(), "Counted Steps", 45),
              _buildListTile(_formatAvgCadence(_countedSteps, _duration),
                  "Avg. Cadence", 45),
              Spacer(),
              _buildControlButtons(),
              Spacer(),
            ],
          );
  }

  /**
   * Erstellt die Buttons
   */
  Widget _buildControlButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButton(
          onPressed: startStopStepCount,
          label: _startStepCount ? "Stop Counting" : "Start Counting",
        ),
        _buildButton(
          onPressed: _startStepCount ? null : _resetStepCount,
          label: "Reset Steps",
        ),
      ],
    );
  }

  /**
   * Abstrahiert die Textausgabe um Codeduplikate zu vermeiden
   */
  Widget _buildListTile(
      String leadingText, String trailingText, double fontSize) {
    return ListTile(
      contentPadding: EdgeInsets.all(8),
      title: Center(child: _buildText(leadingText, fontSize)),
      subtitle: Center(
          child: Text(
        trailingText,
        style: TextStyle(fontSize: fontSize * 0.6),
        textAlign: TextAlign.center,
      )),
    );
  }

  /**
   * Erstellt ein Text Widget in der gegebenen Textgröße
   */
  Widget _buildText(String text, double fontSize) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Digital',
        fontSize: fontSize,
        fontWeight: FontWeight.normal,
      ),
    );
  }

  /**
   * Erstellt ein Widget das einen Button verwaltet und bei Bestätigen des Button eine Funktion ausführt.
   */
  Widget _buildButton({VoidCallback? onPressed, required String label}) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: Size(300, 50),
          backgroundColor: _startStepCount
              ? Color(0xfff27777)
              : Theme.of(context).colorScheme.secondary,
          foregroundColor: Colors.black,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 30),
        ),
      ),
    );
  }
}
