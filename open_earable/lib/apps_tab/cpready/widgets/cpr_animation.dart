import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Widget that displays an animation showcasing an example CPR procedure.
///
/// The animation consists of a SizedBox with the measurements [height] x [width].
/// The animation is started when the widget is initialized and ended when disposed.
class CprAnimation extends StatefulWidget {
  const CprAnimation({
    required double height,
    required double width,
    super.key,
  })  : _height = height,
        _width = width;

  /// The height of the resulting animation.
  final double _height;

  /// The width of the resulting animation.
  final double _width;

  @override
  State<CprAnimation> createState() => _CprAnimationState();
}

class _CprAnimationState extends State<CprAnimation> {
  /// The paths of the images to be included in the animation.
  final List<String> _imagesPaths = [
    "lib/apps_tab/cpready/assets/CPRBottom.svg",
    "lib/apps_tab/cpready/assets/CPRTop.svg",
  ];

  /// The time an image is displayed in milliseconds.
  final int _imageTime = 440;

  /// The index of the current image.
  int _currentIndex = 0;

  /// The timer for switching the image.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    setState(() {
      _timer = Timer.periodic(Duration(milliseconds: _imageTime), (timer) {
        _updateImage();
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _timer = null;
  }

  /// Updates the image that is currently displayed by increasing the index.
  /// The index is reset to the first image when the last image was previously shown.
  void _updateImage() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _imagesPaths.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _imagesPaths[_currentIndex],
      height: widget._height,
      width: widget._width,
    );
  }
}
