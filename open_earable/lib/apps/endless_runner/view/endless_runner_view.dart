import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/endless_runner/model/attitude_tracker.dart';
import 'package:provider/provider.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_kalman/simple_kalman.dart';

import '../../../sensor_data_tab/sensor_chart.dart';
import '../view_model/endless_runner_view_model.dart';

class EndlessRunnerView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  EndlessRunnerView(this._tracker, this._openEarable);

  @override
  State<EndlessRunnerView> createState() => _EndlessRunnerViewState(_openEarable);
}

class _EndlessRunnerViewState extends State<EndlessRunnerView> {
  final OpenEarable _openEarable;
  late final EndlessRunnerViewModel _viewModel;
  _EndlessRunnerViewState(this._openEarable);

  //measured datapoints
  late List<XYZValue> _data = [];
  StreamSubscription? _dataSubscription;
  late SimpleKalman kalmanX, kalmanY, kalmanZ;
  final errorMeasure = 5.0;

  late int highscore = 0;
  //current score in a run
  late int score = 0;
  var _count_timer;

  //should be calibrated at start of run when different sensor is used
  double _calibrated_Z = 9.0;

  //values for jogging
  //amount of datapoints checked for jogging motion
  int _check_jog = 50;
  //counts up until enough datapoints have been accumulated
  int _check_counter = 0;
  //difference of the calibrated Z value for accepting jogging motion
  double _threshold_jog = 2.0;
  //min number of acceptable changes in rises/falls
  int _jog_min_changes = 5;
  bool _been_warned = false;
  int _warnings = 0;
  int _max_warnings = 3;
  int _jingle_running_not_detected = 8;
  int _jingle_run_end = 7;

  //counter for next challenge
  int _challenge_counter = 5;
  Random _random = new Random();
  int _challenge_number = 0;
  int _challenge_fail_counter = 0;
  int _buffer_after_challenge = 0;
  int _jingle_challenge_success = 1;

  //values for measuring jumping
  //difference of the calibrated Z value for accepting jumping motion
  double _jump_threshold = 5.0;
  //amount of datapoints that have to be over the threshold to be considered a jump
  int _jump_peak_length = 6;
  int _peak_counter = 0;
  int _jingle_jump = 4;

  //values for measuring push up (looks for chaos in x value)
  //min X value for accepting value changes in push up motion
  double _push_up_threshold = 3.0;
  //min number of acceptable changes in rises/falls
  int _push_up_min_changes = 10;
  //amount of last datapoints checked
  int _push_up_check_interval = 50;
  int _jingle_push_up = 2;

  var _jingles_mapped;

  @override
  void initState() {
    this._loadHighscore();
    super.initState();
    this._viewModel = EndlessRunnerViewModel(widget._tracker);
    _jingles_mapped = {
      'Run End': this._jingle_run_end,
      'Jogging Not Detected': this._jingle_running_not_detected,
      'Challenge Success': this._jingle_challenge_success,
      'Jump!': this._jingle_jump,
      'Push Up!': this._jingle_push_up
    };
    _setupListeners();
  }

  @override
  void dispose() {
    print("dispose");
    super.dispose();
    _dataSubscription?.cancel();
  }

  void _setupListeners() {
    if (!_openEarable.bleManager.connected) return;
    kalmanX = SimpleKalman(
        errorMeasure: errorMeasure,
        errorEstimate: errorMeasure,
        q: 0.9);
    kalmanY = SimpleKalman(
        errorMeasure: errorMeasure,
        errorEstimate: errorMeasure,
        q: 0.9);
    kalmanZ = SimpleKalman(
        errorMeasure: errorMeasure,
        errorEstimate: errorMeasure,
        q: 0.9);
    _dataSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
          int timestamp = data["timestamp"];
          /*
        XYZValue accelerometerValue = XYZValue(
            timestamp: timestamp,
            x: data["ACC"]["X"],
            y: data["ACC"]["Y"],
            z: data["ACC"]["Z"],
            units: data["ACC"]["units"]);
        */
          XYZValue xyzValue = XYZValue(
              timestamp: timestamp,
              z: kalmanZ.filtered(data['ACC']["Z"]),
              x: kalmanX.filtered(data['ACC']["X"]),
              y: kalmanY.filtered(data['ACC']["Y"]),
              units: data['ACC']["units"]);

          _updateData(xyzValue);
        });
  }

  void _updateData(XYZValue value) {
    //do not change data if run is stopped
    if (!_viewModel.isTracking || !mounted) {
      return;
    }
    setState(() {
      /*
      NECESSARY AS MULTIPLE DATASTREAMS ARE ACCUMULATED EVEN AFTER DISPOSING
      BLOCKS STREAM IF ANOTHER STREAM HAS ADDED THE DATA ALREADY
      */
      if (this._data.length >= 2 && (value.timestamp == this._data[this._data.length-1].timestamp || value.timestamp == this._data[this._data.length-2].timestamp)) {
        return;
      }

      this._data.add(value);
      if (this._data.length > this._check_jog) {
        this._data.removeRange(0, this._data.length - this._check_jog);
      }
      _checkMotion();
    });
  }

  //determines which motion should be checked for currently
  void _checkMotion() {
    if (this._challenge_counter == 0) {
      switch (this._challenge_number) {
        case 1:
          this._checkJumping();
        case 2:
          this._checkPushUp();
      }
    } else {
      if (this._buffer_after_challenge > 0) {
        this._buffer_after_challenge--;
        return;
      }
      //check if user is jogging after enough new datapoints
      this._check_counter++ >= this._check_jog ? this._checkRunning() : Null;
    }
  }

  //checks for jumping
  void _checkJumping() {
    if (this._data.last.z > (this._calibrated_Z + this._jump_threshold)) {
      //success
      if (++this._peak_counter >= this._jump_peak_length) _successfulJump();
    } else {
        this._peak_counter = 0;
    }
    //fail
    if (--this._challenge_fail_counter < 0) this._stopRun();
  }

  //called after successful jump
  void _successfulJump() {
    _openEarable.audioPlayer.jingle(this._jingles_mapped['Challenge Success']);
    //lower counter with higher score
    this._challenge_counter = max(1, 5 - (this.score ~/ 20)) + this._random.nextInt(5);
    this._peak_counter = 0;
    this._buffer_after_challenge = 25;
    this._countUp();
  }

  //checks for push up
  void _checkPushUp() {
    int changes = 0;
    double prev_x = this._data.last.x;
    bool rise = prev_x < this._data[_data.length - 2].x;
    for (int i = 0; i < this._push_up_check_interval; i++) {
      if (this._data[this._data.length - i - 1].x < this._push_up_threshold) continue;
      if (rise && this._data[this._data.length - i - 1].x < prev_x) {
        rise = false;
        changes++;
      } else if (!rise && this._data[this._data.length - i - 1].x > prev_x) {
        rise = true;
        changes++;
      }
      prev_x = this._data[this._data.length - i - 1].x;
    }
    //success
    if (changes >= this._push_up_min_changes) _successfulPushUp();
    //fail
    if (--this._challenge_fail_counter < 0) this._stopRun();
  }

  //called after successful push up
  void _successfulPushUp() {
    _openEarable.audioPlayer.jingle(this._jingles_mapped['Challenge Success']);
    //lower counter with higher score
    this._challenge_counter = max(1, 5 - (this.score ~/ 20)) + this._random.nextInt(5);
    this._peak_counter = 0;
    this._buffer_after_challenge = 50;
    this._countUp();
  }

  //checks if user is running
  void _checkRunning() {
    this._check_counter = 0;
    int changes = 0;
    bool above = (this._data[0].z > this._calibrated_Z);
    for (int i = 0; i < this._check_jog; i++) {
      if (!above && this._data[i].z > (this._calibrated_Z + this._threshold_jog)) { //rise
        above = true;
        changes++;
      } else if (above && this._data[i].z < (this._calibrated_Z - this._threshold_jog)) { //fall
        above = false;
        changes++;
      }
    }
    if (changes >= this._jog_min_changes) { //user is running
      if (this._been_warned) this._countUp();
      this._been_warned = false;
      this._warnings = max(0, this._warnings - 1);
    } else { //user is not running / not fast enough
      if (this._warnings++ >= this._max_warnings) {
        print("yeah");
        this._stopRun();
      } else {
        _openEarable.audioPlayer.jingle(this._jingles_mapped['Jogging Not Detected']);
      }
      this._been_warned = true;
      this._stopCount();
      return;
    }

    this._challenge_counter--;
    //start challenge
    if (_challenge_counter == 0) {
      _startChallenge();
    }
  }

  //called on challenge start
  void _startChallenge() {
    this._stopCount();
    this._challenge_number = 1 + this._random.nextInt(2);
    switch (this._challenge_number) {
      case 1:
        _openEarable.audioPlayer.jingle(this._jingles_mapped['Jump!']);
        _challenge_fail_counter = max(50, 200 - (this.score ~/ 2));
      case 2:
        _openEarable.audioPlayer.jingle(this._jingles_mapped['Push Up!']);
        _challenge_fail_counter = max(50, 200 - (this.score ~/ 2));
    }
  }

  //load highscore from local data
  void _loadHighscore() async{
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highscore = prefs.getInt('highscore') ?? 0;
    });
  }

  //set highscore, depends on current score
  void _setHighscore() async{
    if (this.score < this.highscore) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      this.highscore = this.score;
      prefs.setInt('highscore', this.highscore);
    });
  }

  //starts score count
  void _countUp() {
    if (!mounted) {
      return;
    }
    setState(() {
      this.score += 1;
    });
    const interval = Duration(seconds:1);
    this._count_timer = Timer(interval, () {this._countUp();});
  }

  //stops score count
  void _stopCount() {
    this._count_timer.cancel();
  }

  //called when starting a run
  void _startRun() {
    this._viewModel.startTracking();
    setState(() {
      this.score = -1;
    });
    this._countUp();
  }

  //called when stopping a run
  void _stopRun() {
    _openEarable.audioPlayer.jingle(this._jingle_run_end);
    _viewModel.stopTracking();
    this._stopCount();
    this._setHighscore();
    this._warnings = 0;
    this._challenge_counter = 5;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EndlessRunnerViewModel>.value(
      value: _viewModel,
      builder: (context, child) => Consumer<EndlessRunnerViewModel>(
        builder: (context, endlessRunnerViewerModel, child) => PopScope(
            canPop: true,
            onPopInvoked: (didPop) {endlessRunnerViewerModel.isTracking ? this._stopRun() : Null;},
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.background,
              appBar: AppBar(
                title: Text('Endless Runner'),
              ),
              body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      //highscore
                      Text('HIGHSCORE: $highscore',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      //start button
                      this._buildStartButton(endlessRunnerViewerModel),
                      //current score
                      Container(
                          padding: EdgeInsets.all(20.0),
                          width: 300,
                          color: Colors.black45,
                          child: Center(
                            child:Text('Current Score: $score'),
                          )
                      ),
                      SizedBox(height: 20),
                      //sound legend
                      this._buildSoundLegend(),
                    ]),
              ),
            )
        )
      )
    );
  }

  Widget _buildStartButton(EndlessRunnerViewModel endlessRunnerViewerModel) {
    return Column(children: [
      ElevatedButton(
        onPressed: endlessRunnerViewerModel.isAvailable
            ? () { endlessRunnerViewerModel.isTracking ? this._stopRun() :
              this._startRun(); }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: !endlessRunnerViewerModel.isTracking ? Color(0xff77F2A1) : Color(0xfff27777),
          foregroundColor: Colors.black,
        ),
        child: endlessRunnerViewerModel.isTracking ? const Text("Stop Run") : const Text("Start Run"),
      ),
      Visibility(
        visible: !endlessRunnerViewerModel.isAvailable,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: Text(
          "No Earable Connected",
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      ),
    ]);
  }

  Widget _buildSoundLegend() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Run End'),
            IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () {
                _openEarable.audioPlayer.jingle(this._jingles_mapped['Run End']);
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Jogging Not Detected'),
            IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () {
                _openEarable.audioPlayer.jingle(this._jingles_mapped['Jogging Not Detected']);
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Jump!'),
            IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () {
                _openEarable.audioPlayer.jingle(this._jingles_mapped['Jump!']);
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Push Up!'),
            IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () {
                _openEarable.audioPlayer.jingle(this._jingles_mapped['Push Up!']);
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Challenge Success'),
            IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () {
                _openEarable.audioPlayer.jingle(this._jingles_mapped['Challenge Success']);
              },
            ),
          ],
        ),
      ],
    );
  }
}