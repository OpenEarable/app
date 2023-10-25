import 'dart:async';

import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'dart:math';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:simple_kalman/simple_kalman.dart';
import '../utils/madgwick_ahrs.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three3d/math/euler.dart';
import 'package:flutter/foundation.dart';

class SensorDataTab extends StatefulWidget {
  final OpenEarable _openEarable;
  SensorDataTab(this._openEarable);
  @override
  _SensorDataTabState createState() => _SensorDataTabState(_openEarable);
}

class _SensorDataTabState extends State<SensorDataTab>
    with SingleTickerProviderStateMixin {
  final String fileName = "assets/OpenEarable.obj";
  Euler _euler = Euler(0, 0, 0, "YZX");

  late FlutterGlPlugin three3dRender;
  three.WebGLRenderer? renderer;

  int? fboId;
  late double width;
  late double height;

  Size? screenSize;

  late three.Scene scene;
  three.Color _sceneBackground = three.Color.fromArray([0, 0, 0]);
  bool _sceneInitialized = false;
  late three.Camera camera;
  late three.Mesh mesh;

  double dpr = 1.0;

  var amount = 4;

  bool verbose = true;
  bool disposed = false;

  late three.Object3D object;

  late three.Texture texture;

  late three.WebGLRenderTarget renderTarget;

  dynamic sourceTexture;

  //late EarableModel _earableModel;
  final OpenEarable _openEarable;
  late TabController _tabController;
  late int _minX;
  late int _maxX;
  StreamSubscription? _imuSubscription;
  StreamSubscription? _barometerSubscription;
  StreamSubscription? _batteryLevelSubscription;
  StreamSubscription? _buttonStateSubscription;
  late MadgwickAHRS madgwickAHRS;
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
    //_earableModel = EarableModel(fileName: "assets/OpenEarable.obj");

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
          if (_tabController.index == 4) {
            accelerometerData = [];
            magnetometerData = [];
            barometerData = [];
          }
        });
      }
    });
    _minX = 0;
    _maxX = _numDatapoints;
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
    madgwickAHRS = MadgwickAHRS();
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

  int lastTimestamp = 0;
  _setupListeners() {
    _batteryLevelSubscription =
        _openEarable.sensorManager.getBatteryLevelStream().listen((data) {
      print("Battery level is ${data[0]}");
    });
    _buttonStateSubscription =
        _openEarable.sensorManager.getButtonStateStream().listen((data) {
      print("Button State is ${data[0]}");
    });
    _imuSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      int timestamp = data["timestamp"];
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

      if (_tabVisibility[4]) {
        setState(() {
          // Yaw (around Z-axis)
          _yaw = data["EULER"]["YAW"];
          // Pitch (around Y-axis)
          _pitch = data["EULER"]["PITCH"];
          // Roll (around X-axis)
          _roll = data["EULER"]["ROLL"];
        });
        updateRotation(roll: _roll, pitch: _pitch, yaw: _yaw);
        //_earableModel.updateRotation(_qw, _qx, _qy, _qz);
      } else {
        setState(() {
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
      if (!_tabVisibility[4]) {
        setState(() {
          barometerData.add(barometerValue);
          _checkLength(barometerData);
        });
      }
    });
  }

  _checkLength(data) {
    if (data.length > _numDatapoints) {
      data.removeRange(0, data.length - _numDatapoints);
    }
  }

  @override
  void dispose() {
    three3dRender.dispose();
    _imuSubscription?.cancel();
    _barometerSubscription?.cancel();
    _buttonStateSubscription?.cancel();
    _batteryLevelSubscription?.cancel();
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
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight), // Default AppBar height
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white, // Color of the underline indicator
          labelColor: Colors.white, // Color of the active tab label
          unselectedLabelColor: Colors.grey, // Color of the inactive tab labels
          tabs: [
            Tab(text: 'Accel.'),
            Tab(text: 'Gyro.'),
            Tab(text: 'Magnet.'),
            Tab(text: 'Pressure'),
            Tab(text: '3D'),
          ],
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
        Expanded(child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            width = constraints.maxWidth;
            height = constraints.maxHeight;
            Color c = Theme.of(context).colorScheme.background;
            _sceneBackground = three.Color.fromArray([c.red, c.green, c.blue]);
            initSize(context);
            return Column(
              children: [
                Stack(
                  children: [
                    Container(
                        width: width,
                        height: height,
                        color: Theme.of(context).colorScheme.background,
                        child: Builder(builder: (BuildContext context) {
                          if (kIsWeb) {
                            return three3dRender.isInitialized
                                ? HtmlElementView(
                                    viewType:
                                        three3dRender.textureId!.toString())
                                : Container();
                          } else {
                            return three3dRender.isInitialized
                                ? Texture(textureId: three3dRender.textureId!)
                                : Container();
                          }
                        })),
                  ],
                ),
              ],
            );
          },
        )),
        Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
                "Yaw: ${(_yaw * 180 / pi).toStringAsFixed(1)}°\nPitch: ${(-_pitch * 180 / pi).toStringAsFixed(1)}°\nRoll: ${(_roll * 180 / pi).toStringAsFixed(1)}°"))
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

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    //width = screenSize!.width;
    //height = screenSize!.height;

    three3dRender = FlutterGlPlugin();

    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": width.toInt(),
      "height": height.toInt(),
      "dpr": dpr
    };

    await three3dRender.initialize(options: options);
    // Wait for web
    Future.delayed(const Duration(milliseconds: 100), () async {
      await three3dRender.prepareContext();

      initScene();
    });
  }

  initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mqd = MediaQuery.of(context);

    screenSize = mqd.size;
    dpr = mqd.devicePixelRatio;

    initPlatformState();
  }

  void updateRotation({
    required double yaw,
    required double pitch,
    required double roll,
  }) {
    _yaw = yaw;
    _pitch = pitch;
    _roll = roll;
    if (_sceneInitialized && three3dRender.isInitialized) {
      render();
    }
  }

  render() {
    _euler.x = _roll;
    _euler.y = _yaw;
    _euler.z = _pitch;
    _euler.order = "YZX";
    //object.rotation = _euler;
    //object.quaternion = three.Quaternion(0, 1, 0, 0);
    object.setRotationFromEuler(_euler);
    //object.setRotationFromAxisAngle(axis, angle)
    //object.rotateY(_yaw);
    //object.rotateZ(_pitch);
    //object.rotateX(_roll);

    int t = DateTime.now().millisecondsSinceEpoch;

    final gl = three3dRender.gl;
    scene.add(three.AxesHelper(75));
    scene.castShadow = false;
    scene.receiveShadow = false;
    renderer!.alpha = true;
    renderer!.render(scene, camera);

    int t1 = DateTime.now().millisecondsSinceEpoch;

    if (verbose) {
      print("render cost: ${t1 - t} ");
      print(renderer!.info.memory);
      print(renderer!.info.render);
    }

    // 重要 更新纹理之前一定要调用 确保gl程序执行完毕
    gl.flush();

    if (verbose) print(" render: sourceTexture: $sourceTexture ");

    if (!kIsWeb) {
      three3dRender.updateTexture(sourceTexture);
    }
  }

  initRenderer() {
    Map<String, dynamic> options = {
      "width": width,
      "height": height,
      "gl": three3dRender.gl,
      "antialias": true,
      "canvas": three3dRender.element,
    };
    renderer = three.WebGLRenderer(options);
    renderer!.setPixelRatio(dpr);
    renderer!.setSize(width, height, false);
    renderer!.shadowMap.enabled = false;

    if (!kIsWeb) {
      var pars = three.WebGLRenderTargetOptions({"format": three.RGBAFormat});
      renderTarget = three.WebGLRenderTarget(
          (width * dpr).toInt(), (height * dpr).toInt(), pars);
      renderTarget.samples = 4;
      renderer!.setRenderTarget(renderTarget);
      sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget);
    }
  }

  initScene() async {
    initRenderer();
    await initPage();
    _sceneInitialized = true;
  }

  initPage() async {
    camera = three.PerspectiveCamera(45, width / height, 1, 2000);
    camera.position.z = 250;
    camera.position.x = 50;
    camera.position.y = 50;
    camera.lookAt(three.Vector3(0, 0, 0));

    // scene

    scene = three.Scene();

    var ambientLight = three.AmbientLight(0xcccccc, 0.4);
    scene.add(ambientLight);

    var pointLight = three.PointLight(0xffffff, 0.8);
    camera.add(pointLight);
    scene.add(camera);

    var loader = three_jsm.OBJLoader(null);
    object = await loader.loadAsync(fileName);

    //object.scale.set(0.5, 0.5, 0.5);
    scene.add(object);
    scene.background = _sceneBackground;
    animate();
  }

  animate() {
    if (disposed) {
      return;
    }
    _yaw += 0.05;
    //_pitch += 0.5;
    //_roll += 0.5;
    render();
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
