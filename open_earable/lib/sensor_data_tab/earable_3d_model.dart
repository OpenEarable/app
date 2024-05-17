import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Earable3DModel extends StatefulWidget {
  final OpenEarable _openEarable;
  Earable3DModel(this._openEarable);
  @override
  _Earable3DModelState createState() => _Earable3DModelState(_openEarable);
}

class _Earable3DModelState extends State<Earable3DModel> {
  WebViewController? _controller;
  OpenEarable _openEarable;
  _Earable3DModelState(this._openEarable);
  StreamSubscription? _imuSubscription;
  double _pitch = 0;
  double _yaw = 0;
  double _roll = 0;

  final String fileName = "assets/OpenEarable.obj";

  dynamic sourceTexture;
  @override
  void initState() {
    super.initState();
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
  }

  @override
  void didUpdateWidget(covariant Earable3DModel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._openEarable != widget._openEarable) {
      setState(() {
        _openEarable = widget._openEarable;
      });
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
    if (!_openEarable.bleManager.connected) {
      return;
    }
    _imuSubscription?.cancel();
    _imuSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      setState(() {
        _yaw = data["EULER"]["YAW"];
        _pitch = data["EULER"]["PITCH"];
        _roll = data["EULER"]["ROLL"];
      });
      _controller?.runJavaScript(
          "document.querySelector('model-viewer').setAttribute('orientation', '${-_pitch} ${_roll} ${-_yaw}');");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Expanded(
          child: ModelViewer(
              cameraControls: false,
              backgroundColor: Theme.of(context).colorScheme.background,
              src: 'assets/OpenEarableV2-L.glb',
              alt: 'A 3D model of an astronaut',
              interactionPrompt: InteractionPrompt.none,
              autoRotate: false,
              disableZoom: true,
              disablePan: true,
              onWebViewCreated: (controller) {
                _controller = controller;
                controller.runJavaScript(
                    "document.body.style.overflow = 'hidden';" +
                        "document.documentElement.style.overflow = 'hidden';" +
                        "document.addEventListener('touchmove', function(e) { e.preventDefault(); }, { passive: false });");
              })),
      Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
              "Yaw: ${(_yaw * 180 / pi).toStringAsFixed(1)}°\nPitch: ${(_pitch * 180 / pi).toStringAsFixed(1)}°\nRoll: ${(_roll * 180 / pi).toStringAsFixed(1)}°"))
    ]);
  }
}
