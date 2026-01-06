import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:playback_capture/playback_capture.dart';

class AudioRecorderView extends StatefulWidget {
  const AudioRecorderView({super.key});

  @override
  State<AudioRecorderView> createState() => _AudioRecorderViewState();
}

class _AudioRecorderViewState extends State<AudioRecorderView> {
  bool _isRecording = false;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("Audio Recorder"),
      ),
      body: Center(
        child: PlatformElevatedButton(
          child:
              PlatformText(_isRecording ? "Stop Recording" : "Start Recording"),
          onPressed: () => (), //_toggleRecording,
        ),
      ),
    );
  }

  // Recording logic here...
}
