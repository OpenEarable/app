import 'package:flutter/material.dart';
import 'package:circular_menu/circular_menu.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/widgets/earable_not_connected_warning.dart';
import 'dart:async';
import 'dart:io';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'package:open_earable/main.dart';
import 'package:open_earable/apps/gym_spotter/howToView.dart';

class Spot extends StatefulWidget {
  final OpenEarable _openEarable;
  Spot(this._openEarable);
  @override
  State<Spot> createState() => _SpotState(_openEarable);
}

class _SpotState extends State<Spot> {
  final OpenEarable _openEarable;
  StreamSubscription? _imuSubscription;
  _SpotState(this._openEarable);

  _setupListener() {
    _imuSubscription = _openEarable.sensorManager.subscribeToSensorData(0).listen(
      {}
      cancelOnError: true)
  }

  @override
  void initState() {
    super.initState();
    _setupListener();
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
  }








  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Text('GYMKnopf'),
        ),
        floatingActionButton: CircularMenu(
          alignment: Alignment.bottomRight,
          items: [
            CircularMenuItem(
                icon: Icons.question_mark,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => HowToRoute()));
                }),
            CircularMenuItem(icon: Icons.fitbit_sharp, onTap: () {}),
          ],
        ));
  }
}



// commom mistakes: koopf nicht gerade gemacht, holkreuz -> keine spannung im bauch. schultern hängen lassen. 
