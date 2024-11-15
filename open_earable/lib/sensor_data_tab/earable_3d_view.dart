import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ModelViewerWidget extends StatefulWidget {
  final String modelSrc;
  final Color backgroundColor;
  final bool cameraControls;
  final bool autoRotate;
  final bool disableZoom;
  final bool disablePan;

  const ModelViewerWidget({
    required this.modelSrc,
    required this.backgroundColor,
    this.cameraControls = false,
    this.autoRotate = false,
    this.disableZoom = true,
    this.disablePan = true,
    super.key,
  });

  @override
  State<ModelViewerWidget> createState() => ModelViewerWidgetState();
}

class ModelViewerWidgetState extends State<ModelViewerWidget> {
  WebViewController? _controller;

  void updateOrientation(double pitch, double yaw, double roll) {
    if (_controller != null) {
      final jsCommand = "document.querySelector('model-viewer').setAttribute('orientation', '${-pitch} $roll ${-yaw}');";
      _controller?.runJavaScript(jsCommand);
    } else {
      print("WebViewController is not initialized yet.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModelViewer(
      cameraControls: widget.cameraControls,
      backgroundColor: widget.backgroundColor,
      src: widget.modelSrc,
      alt: 'A 3D model of the OpenEarable',
      interactionPrompt: InteractionPrompt.none,
      autoRotate: widget.autoRotate,
      disableZoom: widget.disableZoom,
      disablePan: widget.disablePan,
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.runJavaScript(
          "document.body.style.overflow = 'hidden';document.documentElement.style.overflow = 'hidden';document.addEventListener('touchmove', function(e) { e.preventDefault(); }, { passive: false });",
        );
      },
    );
  }
}
