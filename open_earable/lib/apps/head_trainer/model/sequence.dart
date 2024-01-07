class Sequence {
  String name;
  final List<Move> moves;

  Sequence(this.name, this.moves);

  Sequence copy() {
    return Sequence(name, List.of(moves));
  }

}

class Move {
  final MoveType type;
  final int amountInDegree;
  final int timeInSeconds;
  final int plusMinusDegree;

  Move(this.type, this.amountInDegree, this.timeInSeconds, this.plusMinusDegree);

  Move.defaultPM(MoveType type, int amountInDegree, int timeInSeconds) :
        this(type, amountInDegree, timeInSeconds, _getDefaultPlusMinus(type));

}

_getDefaultPlusMinus(MoveType type) {
  return switch(type) {
    MoveType.tiltForward => 10,
    MoveType.tiltBackwards => 10,
    MoveType.tiltRight => 10,
    MoveType.tiltLeft => 10,
    MoveType.rotateLeft => 25,
    MoveType.rotateRight => 25
  };
}

enum MoveType {
  tiltForward(type: "Tilt", direction: "Forward"),
  tiltBackwards(type: "Tilt", direction: "Backwards"),
  tiltLeft(type: "Tilt", direction: "Left"),
  tiltRight(type: "Tilt", direction: "Right"),
  rotateLeft(type: "Rotate", direction: "Left"),
  rotateRight(type: "Rotate", direction: "Right");

  const MoveType({
    required this.type,
    required this.direction,
  });

  final String type;
  final String direction;

}