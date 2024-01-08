/**
 * Position Object with x, y and z coordinate
 */
class Position {
  ///threshold for a difference to be recognized as movement
  final double threshold = 5.0;
  double _x;
  double _y;
  double _z;

  Position(this._x, this._y, this._z);

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
    final double xDir = _x - position._x;
    final double yDir = _y - position._y;
    final double zDir = _z - position._z;
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
    return "x: $_x y: $_y z: $_z";
  }
}

/**
 * Object that Contains a movement
 */
class Positions {
  final List<Position> _data = <Position>[];
  late List<Direction> directions = <Direction>[];

  void addPosition(Position pos) {
    _data.add(pos);
    computeDirections();
  }

  /**
   * Method that Computes the directions from the given Positions
   */
  void computeDirections() {
    for (int i = directions.length - 1; i < _data.length - 1; i++) {
      directions.add(_data[i].direction(_data[i + 1]));
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
        _clear();
        return Answer.failed;
      } else if (directions.contains(Direction.down)) {
        return Answer.yes;
      } else {
        return Answer.notEnoughData;
      }
    } else if (directions.contains(Direction.left)) {
      if (directions.contains(Direction.up) ||
          directions.contains(Direction.down)) {
        _clear();
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

  void _clear() {
    _data.clear();
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

enum Answer { yes, no, failed, notEnoughData }
