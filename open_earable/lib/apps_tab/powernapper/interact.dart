import 'package:open_earable_flutter/open_earable_flutter.dart';

///Interaction class for the earable. All actions executed on the earable are accessible through this class.
///For example rings or led colors.
class Interact {
  final OpenEarable _openEarable;

  //Constructor
  Interact(this._openEarable);

  //Getter for the Earable
  OpenEarable getEarable() {
    return _openEarable;
  }

  ///Lets the OpenEarable play the jingel-ID: '1'.
  void ring() {
    try {
      _openEarable.audioPlayer.jingle(1);
    } catch (e) {
      print('ERROR: Jingle konnte nicht gespielt werden!');
    }
  }
}
