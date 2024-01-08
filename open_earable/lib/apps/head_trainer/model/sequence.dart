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
  // amount in degree the move should be performed
  final int amountInDegree;
  // time in seconds the move should be hold
  final int timeInSeconds;
  // leeway in degree for move
  final int plusMinusDegree;

  Move(this.type, this.amountInDegree, this.timeInSeconds, this.plusMinusDegree);

  Move.defaultPM(MoveType type, int amountInDegree, int timeInSeconds) :
        this(type, amountInDegree, timeInSeconds, _getDefaultPlusMinus(type));

}

// Default leeway for different types of moves
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
  // Tilt head forward (pitch axis)
  tiltForward(type: "Tilt", direction: "Forward"),
  // Tilt head backwards (pitch axis)
  tiltBackwards(type: "Tilt", direction: "Backwards"),
  // Tilt head to the left (roll axis)
  tiltLeft(type: "Tilt", direction: "Left"),
  // Tilt head to the right (roll axis)
  tiltRight(type: "Tilt", direction: "Right"),
  // Rotate the head clockwise (yaw axis)
  rotateLeft(type: "Rotate", direction: "Left"),
  // Rotate the head counter clockwise (yaw axis)
  rotateRight(type: "Rotate", direction: "Right");

  const MoveType({
    required this.type,
    required this.direction,
  });

  final String type;
  final String direction;

}