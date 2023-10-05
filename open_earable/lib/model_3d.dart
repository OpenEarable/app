import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three3d/math/euler.dart';
import 'package:three_dart/three3d/renderers/webgl/index.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;

class EarableModel extends StatelessWidget {
  final String fileName;
  Euler _euler = Euler(0, 0, 0, "YZX");
  EarableModel({Key? key, required this.fileName}) : super(key: key);

  late FlutterGlPlugin three3dRender;
  three.WebGLRenderer? renderer;

  int? fboId;
  late double width;
  late double height;

  double _roll = 0;
  double _pitch = 0;
  double _yaw = 0;
  double _qw = 1;
  double _qx = 0;
  double _qy = 0;
  double _qz = 0;

  Size? screenSize;

  late three.Scene scene;
  late three.Camera camera;
  late three.Mesh mesh;

  double dpr = 1.0;

  var amount = 4;

  bool verbose = true;
  bool disposed = false;

  late three.Object3D object;

  //late three.Texture texture;

  late three.WebGLRenderTarget renderTarget;

  dynamic sourceTexture;

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        width = constraints.maxWidth;
        height = constraints.maxHeight;
        initSize(context);
        return Column(
          children: [
            Stack(
              children: [
                Container(
                    width: width,
                    height: height,
                    color: Colors.black,
                    child: Builder(builder: (BuildContext context) {
                      if (kIsWeb) {
                        return three3dRender.isInitialized
                            ? HtmlElementView(
                                viewType: three3dRender.textureId!.toString())
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
    );
  }

  void updateRotation({
    required double yaw,
    required double pitch,
    required double roll,
  }) {
    _yaw = yaw;
    _pitch = pitch;
    _roll = roll;

    render();
  }

  render() {
    _euler.x = _roll;
    _euler.y = _yaw;
    _euler.z = _pitch;
    _euler.order = "YZX";
    object.rotation = _euler;
    //object.quaternion = three.Quaternion(0, 1, 0, 0);
    object.setRotationFromEuler(_euler);
    //object.setRotationFromAxisAngle(axis, angle)
    //object.rotateY(_yaw);
    //object.rotateZ(_pitch);
    //object.rotateX(_roll);

    int t = DateTime.now().millisecondsSinceEpoch;

    final gl = three3dRender.gl;
    scene.add(three.AxesHelper(100));
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
      "canvas": three3dRender.element
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
  }

  initPage() async {
    camera = three.PerspectiveCamera(45, width / height, 1, 2000);
    camera.position.z = 250;

    // scene

    scene = three.Scene();

    var ambientLight = three.AmbientLight(0xcccccc, 0.4);
    scene.add(ambientLight);

    var pointLight = three.PointLight(0xffffff, 0.8);
    camera.add(pointLight);
    scene.add(camera);

    var loader = three_jsm.OBJLoader(null);
    object = await loader.loadAsync('assets/male02.obj');

    //object.scale.set(0.5, 0.5, 0.5);
    scene.add(object);

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

    Future.delayed(Duration(milliseconds: 70), () {
      animate();
    });
  }
}
