class Attitude {
  /// the roll axis attitude in radians
  double roll;
  /// the pitch axis attitude in radians
  double pitch;
  /// the yaw axis attitude in radians
  double yaw;

  Attitude({this.roll = 0, this.pitch = 0, this.yaw = 0});

  /// addition for two attitude objects
  Attitude operator +(Attitude other) {
    return Attitude(
      roll: roll + other.roll,
      pitch: pitch + other.pitch,
      yaw: yaw + other.yaw
    );
  }

  /// subtraction for two attitude objects
  Attitude operator -(Attitude other) {
    return Attitude(
      roll: roll - other.roll,
      pitch: pitch - other.pitch,
      yaw: yaw - other.yaw
    );
  }

  /// multiplication for two attitude objects
  Attitude operator *(double scalar) {
    return Attitude(
      roll: roll * scalar,
      pitch: pitch * scalar,
      yaw: yaw * scalar
    );
  }

  /// division for other attitude
  Attitude operator /(double scalar) {
    return Attitude(
      roll: roll / scalar,
      pitch: pitch / scalar,
      yaw: yaw / scalar
    );
  }
}