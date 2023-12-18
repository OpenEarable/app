class DrivingAttitude {
  /// the roll axis attitude in radians
  double roll;

  /// the pitch axis attitude in radians
  double pitch;

  /// the yaw axis attitude in radians
  double yaw;

  double gyroY;

  DrivingAttitude(
      {this.roll = 0, this.pitch = 0, this.yaw = 0, this.gyroY = 0});

  DrivingAttitude operator +(DrivingAttitude other) {
    return DrivingAttitude(
        roll: roll + other.roll,
        pitch: pitch + other.pitch,
        yaw: yaw + other.yaw,
        gyroY: gyroY + other.gyroY);
  }

  DrivingAttitude operator -(DrivingAttitude other) {
    return DrivingAttitude(
        roll: roll - other.roll,
        pitch: pitch - other.pitch,
        yaw: yaw - other.yaw,
        gyroY: gyroY - other.gyroY);
  }

  DrivingAttitude operator *(double scalar) {
    return DrivingAttitude(
        roll: roll * scalar,
        pitch: pitch * scalar,
        yaw: yaw * scalar,
        gyroY: gyroY * scalar);
  }

  DrivingAttitude operator /(double scalar) {
    return DrivingAttitude(
        roll: roll / scalar,
        pitch: pitch / scalar,
        yaw: yaw / scalar,
        gyroY: gyroY / scalar);
  }
}
