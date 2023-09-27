import 'dart:async';

import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'dart:math';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:ditredi/ditredi.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:simple_kalman/simple_kalman.dart';
import '../utils/mahony_ahrs.dart';
import '../utils/madgwick_ahrs.dart';

class SensorDataTab extends StatefulWidget {
  final OpenEarable _openEarable;
  SensorDataTab(this._openEarable);
  @override
  _SensorDataTabState createState() => _SensorDataTabState(_openEarable);
}

class _SensorDataTabState extends State<SensorDataTab>
    with SingleTickerProviderStateMixin {
  final OpenEarable _openEarable;
  late TabController _tabController;
  late int _minX;
  late int _maxX;
  StreamSubscription? _imuSubscription;
  StreamSubscription? _barometerSubscription;
  late MahonyAHRS mahonyAHRS;
  late MadgwickAHRS madgwickAHRS;
  late DiTreDiController diTreDiController;
  final double errorMeasureAcc = 5;
  final double errorMeasureGyro = 10;
  final double errorMeasureMag = 25;
  late int startTimestamp;
  late SimpleKalman kalmanAX,
      kalmanAY,
      kalmanAZ,
      kalmanGX,
      kalmanGY,
      kalmanGZ,
      kalmanMX,
      kalmanMY,
      kalmanMZ;
  Mesh3D? earableMesh;
  int _numDatapoints = 100;
  List<XYZValue> accelerometerData = [];
  List<XYZValue> gyroscopeData = [];
  List<XYZValue> magnetometerData = [];
  List<BarometerValue> barometerData = [];
  double _pitch = 0;
  double _yaw = 0;
  double _roll = 0;
  _SensorDataTabState(this._openEarable);
  List<bool> _tabVisibility = [
    true,
    false,
    false,
    false,
    false
  ]; // All tabs except the first one are hidden

  @override
  void initState() {
    super.initState();
    startTimestamp = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 200; i++) {
      //var data = XYZValue(timestamp: i, x: -3, y: 2, z: 4, units: {});
      //accelerometerData.add(data);
      //gyroscopeData.add(data);
      //magnetometerData.add(data);
      //barometerData.add(BarometerValue(
      //    timestamp: i, pressure: 100000, temperature: 10, units: {}));
    }
    _tabController = TabController(vsync: this, length: 5);
    _tabController.addListener(() {
      if (_tabController.index != _tabController.previousIndex) {
        setState(() {
          for (int i = 0; i < _tabVisibility.length; i++) {
            _tabVisibility[i] = (i == _tabController.index);
          }
        });
      }
    });
    _minX = 0;
    _maxX = _numDatapoints;
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
    _loadMesh();
    mahonyAHRS = MahonyAHRS();
    madgwickAHRS = MadgwickAHRS();
    diTreDiController = DiTreDiController();
    diTreDiController.update(rotationX: 0, rotationY: 0, rotationZ: 0);
    kalmanAX = SimpleKalman(
        errorMeasure: errorMeasureAcc, errorEstimate: errorMeasureAcc, q: 0.9);
    kalmanAY = SimpleKalman(
        errorMeasure: errorMeasureAcc, errorEstimate: errorMeasureAcc, q: 0.9);
    kalmanAZ = SimpleKalman(
        errorMeasure: errorMeasureAcc, errorEstimate: errorMeasureAcc, q: 0.9);
    kalmanGX = SimpleKalman(
        errorMeasure: errorMeasureGyro,
        errorEstimate: errorMeasureGyro,
        q: 0.9);
    kalmanGY = SimpleKalman(
        errorMeasure: errorMeasureGyro,
        errorEstimate: errorMeasureGyro,
        q: 0.9);
    kalmanGZ = SimpleKalman(
        errorMeasure: errorMeasureGyro,
        errorEstimate: errorMeasureGyro,
        q: 0.9);
    kalmanMX = SimpleKalman(
        errorMeasure: errorMeasureMag, errorEstimate: errorMeasureMag, q: 0.9);
    kalmanMY = SimpleKalman(
        errorMeasure: errorMeasureMag, errorEstimate: errorMeasureMag, q: 0.9);
    kalmanMZ = SimpleKalman(
        errorMeasure: errorMeasureMag, errorEstimate: errorMeasureMag, q: 0.9);
  }

  void _loadMesh() async {
    var mesh = Mesh3D(await ObjParser().loadFromResources("assets/model.obj"));
    setState(() {
      earableMesh = mesh;
    });
  }

  int lastTimestamp = 0;
  _setupListeners() {
    _openEarable.sensorManager.getBatteryLevelStream().listen((data) {
      print("Battery level is ${data[0]}");
    });
    _openEarable.sensorManager.getButtonStateStream().listen((data) {
      print("Button State is ${data[0]}");
    });
    _imuSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      //print(data);
      int timestamp = data["timestamp"];
      if (data["sensorId"] == 0) {
        /*
        XYZValue accelerometerValue = XYZValue(
            timestamp: timestamp,
            x: data["ACC"]["X"],
            y: data["ACC"]["Y"],
            z: data["ACC"]["Z"],
            units: data["ACC"]["units"]);
        XYZValue gyroscopeValue = XYZValue(
            timestamp: timestamp,
            x: data["GYRO"]["X"],
            y: data["GYRO"]["Y"],
            z: data["GYRO"]["Z"],
            units: data["GYRO"]["units"]);
        XYZValue magnetometerValue = XYZValue(
            timestamp: timestamp,
            x: data["MAG"]["X"],
            y: data["MAG"]["Y"],
            z: data["MAG"]["Z"],
            units: data["MAG"]["units"]);
        */
        XYZValue accelerometerValue = XYZValue(
            timestamp: timestamp,
            x: kalmanAX.filtered(data["ACC"]["X"]),
            y: kalmanAY.filtered(data["ACC"]["Y"]),
            z: kalmanAZ.filtered(data["ACC"]["Z"]),
            units: data["ACC"]["units"]);
        XYZValue gyroscopeValue = XYZValue(
            timestamp: timestamp,
            x: kalmanGX.filtered(data["GYRO"]["X"]),
            y: kalmanGY.filtered(data["GYRO"]["Y"]),
            z: kalmanGZ.filtered(data["GYRO"]["Z"]),
            units: data["GYRO"]["units"]);
        XYZValue magnetometerValue = XYZValue(
            timestamp: timestamp,
            x: kalmanMX.filtered(data["MAG"]["X"]),
            y: kalmanMX.filtered(data["MAG"]["Y"]),
            z: kalmanMX.filtered(data["MAG"]["Z"]),
            units: data["MAG"]["units"]);

        double dt = (timestamp - lastTimestamp) / 1000.0;
        mahonyAHRS.update(
            accelerometerValue.x,
            accelerometerValue.y,
            accelerometerValue.z,
            gyroscopeValue.x,
            gyroscopeValue.y,
            gyroscopeValue.z,
            dt);
        lastTimestamp = timestamp;
        List<double> q = mahonyAHRS.quaternion;
        var qw = q[0];
        var qx = q[1];
        var qy = q[2];
        var qz = q[3];
        setState(() {
          // Yaw (around Z-axis)
          _yaw = atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy * qy + qz * qz));
          // Pitch (around Y-axis)
          _pitch = asin(2 * (qw * qy - qx * qz));
          // Roll (around X-axis)
          _roll = atan2(2 * (qw * qx + qy * qz), 1 - 2 * (qx * qx + qy * qy));
          accelerometerData.add(accelerometerValue);
          gyroscopeData.add(gyroscopeValue);
          magnetometerData.add(magnetometerValue);
          _checkLength(accelerometerData);
          _checkLength(gyroscopeData);
          _checkLength(magnetometerData);
          _maxX = accelerometerValue.timestamp;
          _minX = accelerometerData[0].timestamp;
        });
      }
    });

    _barometerSubscription =
        _openEarable.sensorManager.subscribeToSensorData(1).listen((data) {
      Map<dynamic, dynamic> units = {};
      units.addAll(data["BARO"]["units"]);
      units.addAll(data["TEMP"]["units"]);
      int timestamp = data["timestamp"];
      BarometerValue barometerValue = BarometerValue(
          timestamp: timestamp,
          pressure: data["BARO"]["Pressure"],
          temperature: data["TEMP"]["Temperature"],
          units: units);

      setState(() {
        barometerData.add(barometerValue);
        _checkLength(barometerData);
      });
    });
  }

  _checkLength(data) {
    if (data.length > _numDatapoints) {
      data.removeRange(0, data.length - _numDatapoints);
    }
  }

  @override
  void dispose() {
    _imuSubscription?.cancel();
    _barometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_openEarable.bleManager.connected) {
      return _notConnectedWidget();
    } else {
      return _buildSensorDataTabs();
    }
  }

  Widget _notConnectedWidget() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning,
                size: 48,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Center(
                child: Text(
                  "Not connected to\nOpenEarable device",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorDataTabs() {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight), // Default AppBar height
        child: Container(
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white, // Color of the underline indicator
            labelColor: Colors.white, // Color of the active tab label
            unselectedLabelColor:
                Colors.grey, // Color of the inactive tab labels
            tabs: [
              Tab(text: 'Accel.'),
              Tab(text: 'Gyro.'),
              Tab(text: 'Magnet.'),
              Tab(text: 'Pressure'),
              Tab(text: '3D'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Offstage(
            offstage: !_tabVisibility[0],
            child: _buildGraphXYZ('Accelerometer Data', accelerometerData),
          ),
          Offstage(
            offstage: !_tabVisibility[1],
            child: _buildGraphXYZ('Gyroscope Data', gyroscopeData),
          ),
          Offstage(
            offstage: !_tabVisibility[2],
            child: _buildGraphXYZ('Magnetometer Data', magnetometerData),
          ),
          Offstage(
            offstage: !_tabVisibility[3],
            child: _buildGraphXYZ('Pressure Data', barometerData),
          ),
          Offstage(
            offstage: !_tabVisibility[4],
            child: _build3D(),
          ),
        ],
      ),
    );
  }

  Widget _build3D() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          // child: Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Expanded(
            child: DiTreDi(
          figures: [
            Line3D(Vector3(0, 0, 0), Vector3(3, 0, 0),
                width: 4, color: Color.fromARGB(255, 255, 0, 0)),
            Line3D(Vector3(0, 0, 0), Vector3(0, 3, 0),
                width: 4, color: Color.fromARGB(255, 0, 255, 0)),
            Line3D(Vector3(0, 0, 0), Vector3(0, 0, 3),
                width: 4, color: Color.fromARGB(255, 0, 0, 255)),
            TransformModifier3D(
                earableMesh ?? Cube3D(2, Vector3(0, 0, 0)),
                Matrix4.identity()
                  ..rotateY(-_yaw)
                  ..rotateZ(-_pitch)
                  ..rotateX(-_roll))
          ],
          controller: diTreDiController,
        )),
        Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
                "Yaw: ${(_yaw * 180 / pi).toStringAsFixed(1)}°\nPitch: ${(_pitch * 180 / pi).toStringAsFixed(1)}°\nRoll: ${(_roll * 180 / pi).toStringAsFixed(1)}°"))
      ],
    );
  }

  _getColor(String title) {
    if (title == "Accelerometer Data") {
      return ['#FF6347', '#3CB371', '#1E90FF'];
    } else if (title == "Gyroscope Data") {
      return ['#FFD700', '#FF4500', '#D8BFD8'];
    } else if (title == "Magnetometer Data") {
      return ['#F08080', '#98FB98', '#ADD8E6'];
    } else if (title == 'Pressure Data') {
      return ['#32CD32', '#FFA07A'];
    }
  }

  Widget _buildGraphXYZ(String title, List<DataValue> data) {
    List<String> colors = _getColor(title);
    List<charts.Series<dynamic, num>> seriesList = [];
    var minY = -25;
    var maxY = 25;
    if (title == "Magnetometer Data") {
      minY = -200;
      maxY = 200;
    }
    if (title == 'Pressure Data') {
      minY = 0;
      maxY = 130;
      data as List<BarometerValue>;
      seriesList = [
        charts.Series<BarometerValue, int>(
          id: 'Pressure${data.isNotEmpty ? " (${data[0].units['Pressure']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (BarometerValue data, _) => data.timestamp,
          measureFn: (BarometerValue data, _) => data.pressure / 1000,
          data: data,
        ),
        charts.Series<BarometerValue, int>(
          id: 'Temperature${data.isNotEmpty ? " (${data[0].units['Temperature']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[1]),
          domainFn: (BarometerValue data, _) => data.timestamp,
          measureFn: (BarometerValue data, _) => data.temperature,
          data: data,
        ),
      ];
    } else {
      data as List<XYZValue>;
      seriesList = [
        charts.Series<XYZValue, int>(
          id: 'X${data.isNotEmpty ? " (${data[0].units['X']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[0]),
          domainFn: (XYZValue data, _) => data.timestamp,
          measureFn: (XYZValue data, _) => data.x,
          data: data,
        ),
        charts.Series<XYZValue, int>(
          id: 'Y${data.isNotEmpty ? " (${data[0].units['Y']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[1]),
          domainFn: (XYZValue data, _) => data.timestamp,
          measureFn: (XYZValue data, _) => data.y,
          data: data,
        ),
        charts.Series<XYZValue, int>(
          id: 'Z${data.isNotEmpty ? " (${data[0].units['Z']})" : ""}',
          colorFn: (_, __) => charts.Color.fromHex(code: colors[2]),
          domainFn: (XYZValue data, _) => data.timestamp,
          measureFn: (XYZValue data, _) => data.z,
          data: data,
        ),
      ];
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          // child: Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: charts.LineChart(
            seriesList,
            animate: false,
            behaviors: [
              charts.SeriesLegend(
                position: charts.BehaviorPosition
                    .bottom, // To position the legend at the end (bottom). You can change this as per requirement.
                outsideJustification: charts.OutsideJustification
                    .middleDrawArea, // To justify the position.
                horizontalFirst: false, // To stack items horizontally.
                desiredMaxRows:
                    1, // Optional if you want to define max rows for the legend.
                entryTextStyle: charts.TextStyleSpec(
                  // Optional styling for the text.
                  color: charts.Color(r: 255, g: 255, b: 255),
                  fontSize: 12,
                ),
              )
            ],
            primaryMeasureAxis: charts.NumericAxisSpec(
              renderSpec: charts.GridlineRendererSpec(
                labelStyle: charts.TextStyleSpec(
                  fontSize: 14,
                  color: charts.MaterialPalette.white, // Set the color here
                ),
              ),
              viewport: charts.NumericExtents(minY, maxY),
            ),
            domainAxis: charts.NumericAxisSpec(
                renderSpec: charts.GridlineRendererSpec(
                  labelStyle: charts.TextStyleSpec(
                    fontSize: 14,
                    color: charts.MaterialPalette.white, // Set the color here
                  ),
                ),
                viewport: charts.NumericExtents(_minX, _maxX)),
          ),
        ),
      ],
    );
  }
}

abstract class DataValue {
  final int timestamp;
  final Map<dynamic, dynamic> units;
  DataValue({required this.timestamp, required this.units});
}

class XYZValue extends DataValue {
  final double x;
  final double y;
  final double z;

  XYZValue(
      {required timestamp,
      required this.x,
      required this.y,
      required this.z,
      required units})
      : super(timestamp: timestamp, units: units);
  @override
  String toString() {
    return "timestamp: $timestamp\nx: $x, y: $y, z: $z";
  }
}

class BarometerValue extends DataValue {
  final double pressure;
  final double temperature;

  BarometerValue(
      {required timestamp,
      required this.pressure,
      required this.temperature,
      required units})
      : super(timestamp: timestamp, units: units);
  @override
  String toString() {
    return "timestamp: $timestamp\npressure: $pressure, temperature:$temperature";
  }
}
