class Attitude {
  /// the x axis attitude
  double roll;
  /// the y axis attitude
  double pitch;
  /// the z axis attitude
  double yaw;

  Attitude({this.roll = 0, this.pitch = 0, this.yaw = 0});

  Attitude operator +(Attitude other) {
    return Attitude(
      roll: roll + other.roll,
      pitch: pitch + other.pitch,
      yaw: yaw + other.yaw
    );
  }

  Attitude operator -(Attitude other) {
    return Attitude(
      roll: roll - other.roll,
      pitch: pitch - other.pitch,
      yaw: yaw - other.yaw
    );
  }

  Attitude operator *(double scalar) {
    return Attitude(
      roll: roll * scalar,
      pitch: pitch * scalar,
      yaw: yaw * scalar
    );
  }

  Attitude operator /(double scalar) {
    return Attitude(
      roll: roll / scalar,
      pitch: pitch / scalar,
      yaw: yaw / scalar
    );
  }
}