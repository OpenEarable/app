import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/hamster_hurdles_game.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/infoPage.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:simple_kalman/simple_kalman.dart';

class HamsterHurdleApp extends StatefulWidget {
  /// Instance of OpenEarable device.
  final OpenEarable openEarable;

  const HamsterHurdleApp(this.openEarable, {super.key});

  @override
  State<HamsterHurdleApp> createState() => _HamsterHurdleState();
}

class _HamsterHurdleState extends State<HamsterHurdleApp> {

  ///A widget that displays to buttons, on leading to the game and the other
  ///leading to the instruction on how to play the game.
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text("Hamster Hurdles"),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              "lib/apps_tab/hamster_hurdle/assets/start_background.png",
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: screenWidth / 4,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GamePage(
                          openEarable: widget.openEarable,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff8d4223)),
                  child: GameText(text: 'START', fontSize: 18,),
                ),
              ),
              const SizedBox(height: 15,),
              SizedBox(
                  width: screenWidth / 4,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InfoPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff8d4223)),
                    child: GameText(text: 'INFO', fontSize: 18,),
                  ))
            ],
          ),
        ),
      ),
    );
  }
}
