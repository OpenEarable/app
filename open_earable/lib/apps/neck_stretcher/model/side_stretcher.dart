import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// class that defines settings for side to side stretching
class SideStretcherSettings {
  bool isActive;

  /// roll angle threshold for right stretching in degrees
  int rollAngleRight;

  /// roll angle threshold for left stretching in degrees
  int rollAngleLeft;

  /// The time threshold in seconds
  int timeThreshold;

  SideStretcherSettings(
      {this.isActive = true,
      required this.rollAngleRight,
      required this.rollAngleLeft,
      required this.timeThreshold});
}

/// defines side to side stretching
class SideStretcher {
  /// default settings
  SideStretcherSettings _settings = SideStretcherSettings(
    rollAngleRight: 15,
    rollAngleLeft: -15,
    timeThreshold: 10,
  );

  final OpenEarable _openEarable;
  SideStretcherSettings get sideSettings => _settings;

  SideStretcher(this._openEarable);

  /// sets settings
  void setSettings(SideStretcherSettings settings) {
    _settings = settings;
  }

  /// plays jingle
  void alarm() {
    print("playing jingle to end stretching");
    // play jingle
    _openEarable.audioPlayer.jingle(1);
  }
}
