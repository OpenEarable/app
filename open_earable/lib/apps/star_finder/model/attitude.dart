/// Represents the attitude (orientation) of an object in 3D space
/// The attitude is defined by three rotational components: roll, pitch, and yaw.
class Attitude {
  double roll; // The roll component of the attitude, typically represented in degrees
  double pitch; // The pitch component of the attitude, typically represented in degrees
  double yaw; //The yaw component of the attitude, typically represented in degrees

  Attitude({this.roll = 0, this.pitch = 0, this.yaw = 0});

  /// Adds the corresponding components of two Attitude instances
  Attitude operator +(Attitude other) {
    return Attitude(
        roll: roll + other.roll,
        pitch: pitch + other.pitch,
        yaw: yaw + other.yaw);
  }

  /// Subtracts the corresponding components of two Attitude instances.
  Attitude operator -(Attitude other) {
    return Attitude(
        roll: roll - other.roll,
        pitch: pitch - other.pitch,
        yaw: yaw - other.yaw);
  }

  /// Multiplies each component of this Attitude by a scalar value
  Attitude operator *(double scalar) {
    return Attitude(
        roll: roll * scalar, 
        pitch: pitch * scalar, 
        yaw: yaw * scalar);
  }

  /// Divides each component of this Attitude by a scalar value
  Attitude operator /(double scalar) {
    return Attitude(
        roll: roll / scalar,
        pitch: pitch / scalar, 
        yaw: yaw / scalar);
  }
}
