import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/hamster_hurdles_game.dart';

class InfoPage extends StatelessWidget {
  final String duckHeadline = "1. Duck under obstacles";
  final String jumpHeadline = "2. Jump over obstacles";
  final String duckExplanatoryText =
      r"""The app measures acceleration along the Z-axis to detect a ducking motion and a complementary standing motion. For best results, move quickly and powerfully perpendicular to the ground, keeping your head as straight as possible. A quick squat is the best way to achieve this.""";

  final String jumpExplanatoryText =
      r"""A jump is defined in the app mainly by the falling movement after the jump, to clearly distinguish a jump from a ducking movement. Keep your head straight and jump over obstacles.""";
  final String duckImagePath =
      'lib/apps_tab/hamster_hurdle/assets/explanatory_image_duck.jpg';
  final String jumpImagePath =
      'lib/apps_tab/hamster_hurdle/assets/explanatory_image_jump.png';

  const InfoPage({super.key});

  ///A widget that displays an instructional on how to play Hamster Hurdles.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff5b3417),
              Color(0xffaf7a4d),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GameText(
                  text: "HOW TO PLAY",
                  fontSize: 48,
                ),
              ),
              const SizedBox(height: 25),
              FeatureDescriptionRow(
                  headline: duckHeadline,
                  explanatoryText: duckExplanatoryText,
                  pathToImage: duckImagePath),
              const SizedBox(height: 15),
              FeatureDescriptionRow(
                  headline: jumpHeadline,
                  explanatoryText: jumpExplanatoryText,
                  pathToImage: jumpImagePath)
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureDescriptionRow extends StatelessWidget {
  const FeatureDescriptionRow({
    super.key,
    required this.headline,
    required this.explanatoryText,
    required this.pathToImage,
  });

  ///The headline of the explanatory text.
  final String headline;

  ///The explanatory text.
  final String explanatoryText;

  ///The path to the explanatory image.
  final String pathToImage;

  ///A widget that displays a row with an explanatory text and an
  ///explanatory image.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GameText(
                  text: headline,
                  fontSize: 36,
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  explanatoryText,
                  textAlign: TextAlign.start,
                )
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    pathToImage,
                  ),
                  fit: BoxFit.scaleDown,
                ),
              ),
              width: 200,
              height: 300,
            ),
          ),
        ),
      ],
    );
  }
}
