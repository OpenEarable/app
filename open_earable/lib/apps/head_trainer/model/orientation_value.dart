class OrientationValue {

  double roll = 0;
  double pitch = 0;
  double yaw = 0;
  double offsetRoll = 0;
  double offsetPitch = 0;
  double offsetYaw = 0;

  OrientationValue();
  OrientationValue.value(this.roll, this.pitch, this.yaw);
  OrientationValue.offset(this.offsetRoll, this.offsetPitch, this.offsetYaw);

  OrientationValue getWithOffset() {
    return OrientationValue
        .value(roll + offsetRoll, pitch + offsetPitch, yaw + offsetYaw);
  }

  OrientationValue getOffset() {
    return OrientationValue.offset(offsetRoll, offsetPitch, offsetYaw);
  }

  OrientationValue getNegativeAsOffset() {
    return OrientationValue.offset(-roll, -pitch, -yaw);
  }

}