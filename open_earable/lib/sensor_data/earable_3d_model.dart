import 'package:flutter/material.dart';
import 'dart:async';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three3d/math/euler.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'dart:math';

class Earable3DModel extends StatefulWidget {
  final OpenEarable _openEarable;
  Earable3DModel(this._openEarable);
  @override
  _Earable3DModelState createState() => _Earable3DModelState(_openEarable);
}

class _Earable3DModelState extends State<Earable3DModel> {
  final OpenEarable _openEarable;
  _Earable3DModelState(this._openEarable);
  StreamSubscription? _imuSubscription;
  double _pitch = 0;
  double _yaw = 0;
  double _roll = 0;

  final String fileName = "assets/OpenEarable.obj";
  Euler _euler = Euler(0, 0, 0, "YZX");

  late FlutterGlPlugin three3dRender;
  three.WebGLRenderer? renderer;

  int? fboId;
  bool kIsWeb = false;
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
  @override
  void initState() {
    super.initState();
    //_earableModel = EarableModel(fileName: "assets/OpenEarable.obj");
    three3dRender = FlutterGlPlugin();

    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
  }

  int lastTimestamp = 0;
  _setupListeners() {
    _imuSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      // Yaw (around Z-axis)
      _yaw = data["EULER"]["YAW"];
      // Pitch (around Y-axis)
      _pitch = data["EULER"]["PITCH"];
      // Roll (around X-axis)
      _roll = data["EULER"]["ROLL"];
      updateRotation(roll: _roll, pitch: _pitch, yaw: _yaw);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                "Yaw: ${(_yaw * 180 / pi).toStringAsFixed(1)}°\nPitch: ${(_pitch * 180 / pi).toStringAsFixed(1)}°\nRoll: ${(_roll * 180 / pi).toStringAsFixed(1)}°"))
      ],
    );
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
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
    setState(() {});
    // Signs and order of RPY angles need to be swapped to display correctly
    _euler.x = roll;
    _euler.y = -yaw;
    _euler.z = -pitch;
    if (_sceneInitialized && three3dRender.isInitialized) {
      render();
    }
  }

  render() {
    object.setRotationFromEuler(_euler);

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
    _euler.order = "YZX";
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
