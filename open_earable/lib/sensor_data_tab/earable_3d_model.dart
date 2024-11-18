import 'package:flutter/material.dart';
import 'package:open_earable/sensor_data_tab/earable_3d_view.dart' if (dart.library.html) 'package:open_earable/sensor_data_tab/earable_3d_view_web.dart';
import 'dart:async';
import 'dart:math';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class Earable3DModel extends StatefulWidget {
  final OpenEarable openEarable;
  const Earable3DModel(this.openEarable, {super.key});

  @override
  State<Earable3DModel> createState() => _Earable3DModelState();
}

class _Earable3DModelState extends State<Earable3DModel> {
  StreamSubscription? _imuSubscription;
  double _pitch = 0;
  double _yaw = 0;
  double _roll = 0;

  final GlobalKey<ModelViewerWidgetState> _modelViewerKey = GlobalKey();

  final String fileName = 'assets/OpenEarableV1.glb';

  dynamic sourceTexture;

  @override
  void initState() {
    super.initState();
    if (widget.openEarable.bleManager.connected) {
      _setupListeners();
    }
  }

  @override
  void didUpdateWidget(covariant Earable3DModel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openEarable != widget.openEarable) {
      // TODO: Fix this, both widgets hold the same mutable object, so this comparison is pointless
      _setupListeners();
    } else if (_imuSubscription == null) {
      // Workaround for now
      _setupListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
  }

  int lastTimestamp = 0;
  void _setupListeners() {
    if (!widget.openEarable.bleManager.connected) {
      return;
    }
    _imuSubscription?.cancel();
    _imuSubscription =
        widget.openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      setState(() {
        _yaw = data["EULER"]["YAW"];
        _pitch = data["EULER"]["PITCH"];
        _roll = data["EULER"]["ROLL"];
      });
      if (_modelViewerKey.currentState == null) {
        print("ModelViewerKey.currentState is null");
        return;
      }
      _modelViewerKey.currentState?.updateOrientation(_pitch, _yaw, _roll);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Expanded(
        child: ModelViewerWidget(
          key: _modelViewerKey,
          modelSrc: fileName,
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
      ),
      Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
              "Yaw: ${(_yaw * 180 / pi).toStringAsFixed(1)}°\nPitch: ${(_pitch * 180 / pi).toStringAsFixed(1)}°\nRoll: ${(_roll * 180 / pi).toStringAsFixed(1)}°",),),
    ],);
  }
}
