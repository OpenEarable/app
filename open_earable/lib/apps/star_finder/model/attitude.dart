class Attitude {
  /// the x axis attitude
  double x;
  /// the y axis attitude
  double y;
  /// the z axis attitude
  double z;

  Attitude({this.x = 0, this.y = 0, this.z = 0});

  Attitude operator +(Attitude other) {
    return Attitude(
      x: x + other.x,
      y: y + other.y,
      z: z + other.z
    );
  }

  Attitude operator -(Attitude other) {
    return Attitude(
      x: x - other.x,
      y: y - other.y,
      z: z - other.z
    );
  }

  Attitude operator *(double scalar) {
    return Attitude(
      x: x * scalar,
      y: y * scalar,
      z: z * scalar
    );
  }

  Attitude operator /(double scalar) {
    return Attitude(
      x: x / scalar,
      y: y / scalar,
      z: z / scalar
    );
  }
}