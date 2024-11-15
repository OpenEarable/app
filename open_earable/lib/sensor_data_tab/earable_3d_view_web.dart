import 'dart:ui_web';

import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';

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
  final String _viewType = 'model-viewer';

  @override
  void initState() {
    super.initState();

    platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final element = html.Element.tag('model-viewer')
          ..setAttribute('src', widget.modelSrc)
          ..setAttribute('alt', 'A 3D model of the OpenEarable')
          ..style.width = '100%'
          ..style.height = '100%';

        if (widget.cameraControls) {
          element.setAttribute('camera-controls', '');
        }
        if (widget.autoRotate) {
          element.setAttribute('auto-rotate', '');
        }
        if (widget.disableZoom) {
          element.setAttribute('disable-zoom', '');
        }
        if (widget.disablePan) {
          element.setAttribute('disable-pan', '');
        }

        return element;
      },
    );
  }

  void updateOrientation(double pitch, double yaw, double roll) {
    // Find the registered element and update its orientation
    print("Updating orientation: $pitch, $yaw, $roll");
    final element = html.document.querySelector(_viewType);
    if (element != null) {
      element.setAttribute('orientation', '${-pitch} $roll ${-yaw}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
