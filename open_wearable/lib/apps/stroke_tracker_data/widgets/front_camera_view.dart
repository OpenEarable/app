import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FrontCameraView extends StatefulWidget {
  /// Target aspect in landscape (default 16:9) and portrait (default 9:16).
  final double targetAspectLandscape;
  final double targetAspectPortrait;

  /// Crop (cover) like a camera app, or letterbox (contain).
  final BoxFit fit;

  /// Resolution for the camera controller.
  final ResolutionPreset resolution;

  /// Mirror the preview for a selfie look (UI only, not the recorded file).
  final bool mirrorPreview;

  const FrontCameraView({
    super.key,
    this.targetAspectLandscape = 16 / 9,
    this.targetAspectPortrait = 9 / 16,
    this.fit = BoxFit.cover,
    this.resolution = ResolutionPreset.medium,
    this.mirrorPreview = false,
  });

  @override
  State<FrontCameraView> createState() => _FrontCameraViewState();
}

class _FrontCameraViewState extends State<FrontCameraView> {
  CameraController? _controller;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      front,
      widget.resolution,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || _controller == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
        final targetAR = isPortrait ? widget.targetAspectPortrait : widget.targetAspectLandscape;

        // Camera plugin’s aspectRatio is landscape-based (width/height).
        final rawAR = _controller!.value.aspectRatio; // e.g., ~4/3 or ~16/9
        final cameraAR = isPortrait ? 1 / rawAR : rawAR;

        Widget preview = AspectRatio(
          aspectRatio: targetAR,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Size the child by the camera’s natural AR;
              // FittedBox crops (cover) or letterboxes (contain) into targetAR.
              final childHeight = constraints.maxHeight;
              final childWidth = childHeight * cameraAR;

              return FittedBox(
                fit: widget.fit, // cover=crop, contain=letterbox
                child: SizedBox(
                  width: childWidth,
                  height: childHeight,
                  child: CameraPreview(_controller!),
                ),
              );
            },
          ),
        );

        if (widget.mirrorPreview) {
          preview = Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.1415926535897932),
            child: preview,
          );
        }

        return preview;
      },
    );
  }
}
