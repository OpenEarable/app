/**
 * Position Object with x, y and z coordinate
 */
class Position {
  ///threshold for a difference to be recognized as movement
  final double threshold = 2.0;
  final double x;
  final double y;
  final double z;

  Position(this.x, this.y, this.z);

  /**
   * Method to get the direction that another Position is relative to this one
   * only either in y or z direction
   *
   * If below Threshold it will return Idle
   * If there is a higher difference in y and z direction Mix will be returned
   * Otherwise it will be Up/Down for y-Axis and Right/Left for z-Axis
   *
   */
  Direction direction(Position position) {
    final double yDir = y - position.y;
    final double zDir = z - position.z;
    if (yDir.abs() > threshold && zDir.abs() > threshold) {
      return Direction.mix;
    } else if (yDir.abs() < threshold && zDir.abs() < threshold) {
      return Direction.idle;
    } else if (yDir.abs() > threshold) {
      return yDir > 0 ? Direction.up : Direction.down;
    } else {
      return zDir > 0 ? Direction.left : Direction.right;
    }
  }

  String toString() {
    return "x: $x y: $y z: $z";
  }
}

/**
 * Object that Contains a movement
 */
class Directions {
  late List<Direction> directions = <Direction>[];

  void addPosition(Direction direction) {
    if(direction != Direction.idle && direction != Direction.mix) {
      directions.add(direction);
    }
  }

  /**
   * Method that interprets the movement and returns the according Answer
   *
   * If there is movement in the y- and z-Axis it will return Failed
   * If there is not enough data to get an Answer it will return noEnoughData
   * Otherwise it will return yes for movement on y-Axis or no for movement in
   * the z-Axis
   */
  Answer computeAnswer() {
    /// A lot of Ifs to check the different possibilities
    if (directions.contains(Direction.mix)) {
      return Answer.failed;
    } else if (directions.contains(Direction.up)) {
      if (directions.contains(Direction.left) ||
          directions.contains(Direction.right)) {
        clear();
        return Answer.failed;
      } else if (directions.contains(Direction.down)) {
        return Answer.yes;
      } else {
        return Answer.notEnoughData;
      }
    } else if (directions.contains(Direction.left)) {
      if (directions.contains(Direction.up) ||
          directions.contains(Direction.down)) {
        clear();
        return Answer.failed;
      } else if (directions.contains(Direction.right)) {
        return Answer.no;
      } else {
        return Answer.notEnoughData;
      }
    } else {
      return Answer.notEnoughData;
    }
  }

  void clear() {
    directions.clear();
  }
}

enum Direction {
  up,
  down,
  left,
  right,
  mix,
  idle,
}

enum Answer {
  yes,
  no,
  failed,
  notEnoughData
}
