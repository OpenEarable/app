import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AssetVideoPlayer extends StatefulWidget {
  final VideoPlayerController _controller;
  const AssetVideoPlayer({super.key, required VideoPlayerController controller})
      : _controller = controller;

  @override
  State<AssetVideoPlayer> createState() => _AssetVideoPlayerState();
}

class _AssetVideoPlayerState extends State<AssetVideoPlayer> {
  late VideoPlayerController _controller;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = widget._controller;
    _initFuture = _controller.initialize().then((_) {
      setState(() {}); // refresh once ready
    });
    _controller.setLooping(false);
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                VideoPlayer(_controller),
                VideoProgressIndicator(_controller, allowScrubbing: false),
              ],
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
