import 'package:flutter/material.dart';

import '../model/sequence.dart';

class MoveCard extends StatelessWidget {

  final Move move;
  // between 0 and 1
  final double percentFinished;
  // 1 means normal size
  final double size;
  // current degree for move
  final int? currentDegree;

  const MoveCard({
    super.key,
    required this.move,
    this.percentFinished = 0.0,
    this.size = 1,
    this.currentDegree = null,
  });

  String _getText({bool currently = false}) {
    String typeWord = move.type.type;
    if (currently) {
      typeWord = switch (typeWord) {
        "Rotate" => "Rotated",
        "Tilt" => "Tilted",
        String() => "Error",
      };
    }

    bool withToThe = false;
    if (move.type case MoveType.tiltLeft || MoveType.tiltRight
    || MoveType.rotateLeft || MoveType.rotateRight) {
      withToThe = true;
    }

    String result = typeWord + " Head " + move.amountInDegree.toString() + "° ";
    if (withToThe) {
      result += "to the ";
    }
    result += move.type.direction;
    if (!currently) {
      result += " for " + move.timeInSeconds.toString() + "s";
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: size,
      child: Card(
        color: Theme.of(context).colorScheme.primary,
        elevation: 5,
        child: Stack(
          children: [
            _buildBackground(Colors.green),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle(),
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                _getText(),
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        )
    );
  }

  Widget _buildTitle() {
    String degreeText = "";
    if (currentDegree != null) {
      degreeText += currentDegree.toString() + "°/";
    }
    degreeText += move.amountInDegree.toString() + "°";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          move.type.type + " " + move.type.direction,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        Row(
          children: [
            Text(
              degreeText,
              style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.orange
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 8),
              alignment: AlignmentDirectional.centerEnd,
              width: 75,
              child: Text(
                move.timeInSeconds.toString() + "s",
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 24),
              ),
            ),
          ],
        )
      ],
    );
  }


  Widget _buildBackground(Color color) {
    int left = 1;
    int right = 1;
    (left, right) = _calculateRatio(percentFinished);

    return Row(
      children: [
        Expanded(
          flex: left,
          child: Container(
            color: color,
            height: 95,
          ),
        ),
        Expanded(
          flex: right,
          child: Container(
            height: 95,
          ),
        ),
      ],
    );
  }

  (int, int) _calculateRatio(double percentage) {
    const double tolerance = 0.001;

    double left = percentage;
    double right = 1 - percentage;

    for (double i = 1; i < 1000; i++) {
      double x = left * i;
      double y = right * i;

      if ((x - x.round().toDouble()).abs() < tolerance &&
          (y - y.round().toDouble()).abs() < tolerance) {
        return (x.round(), y.round());
      }
    }

    // Now we have a problem
    throw Error();
  }

}
