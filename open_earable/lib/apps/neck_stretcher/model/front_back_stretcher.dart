import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// defines settings for front back stretching
class FrontBackStretcherSettings {
  bool isActive;

  /// pitch angle when the head is tilted to the front
  int pitchAngleForward;

  /// pitch angle when the head is tilted to the back
  int pitchAngleBackward;

  /// time threshold for countdown
  int timeThreshold;

  FrontBackStretcherSettings({this.isActive = true,
    required this.pitchAngleForward,
    required this.pitchAngleBackward,
    required this.timeThreshold});
}

/// class that defines front back stretching
class FrontBackStretcher {
  /// settings
  FrontBackStretcherSettings _settings = FrontBackStretcherSettings(
      pitchAngleForward: 15,
      pitchAngleBackward: -15,
      timeThreshold: 10);

  FrontBackStretcherSettings get frontBackStretcherSettings => _settings;

  final OpenEarable _openEarable;
  
  FrontBackStretcher(this._openEarable);

  /// set settings to new variables
  void setSettings(FrontBackStretcherSettings settings) {
    _settings = settings;
  }

  /// play jingle on earable
  void alarm() {
    print("playing jingle to end stretching");
    // play jingle
    _openEarable.audioPlayer.jingle(1);
  }
  
}
