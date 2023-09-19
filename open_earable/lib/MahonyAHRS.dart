// Code from https://github.com/nelsonwenner/mobile-sensors-filter-mahony/
import 'dart:math';

class MahonyAHRS {
  double _defaultFrequency = 512.0; // (1.0 / 512.0) sample frequency in Hz
  late double _sampleFrequency; // frequency;
  late double _qW; // data quaternion
  late double _qX; // data quaternion
  late double _qY; // data quaternion
  late double _qZ; // data quaternion
  late double _integralFbX; // apply integral feedback
  late double _integralFbY; // apply integral feedback
  late double _integralFbZ; // apply integral feedback
  late double _ki; // 2 * integral gain (Ki), (2.0 * 0.0) = 0.0
  late double _kp; // 2 * proportional gain (Kp), (2.0 * 0.5) = 1.0

  MahonyAHRS() {
    this._sampleFrequency = 1; // (1.0 / 512.0) maximum precision
    this._qW = 1.0;
    this._qX = 0.0;
    this._qY = 0.0;
    this._qZ = 0.0;
    this._integralFbX = 0.0;
    this._integralFbY = 0.0;
    this._integralFbZ = 0.0;
    this._kp = 1.0;
    this._ki = 0.0;
  }

  List<double> get Quaternion => [this._qW, this._qX, this._qY, this._qZ];

  void resetValues() {
    this._qW = 1.0;
    this._qX = 0.0;
    this._qY = 0.0;
    this._qZ = 0.0;
    this._integralFbX = 0.0;
    this._integralFbY = 0.0;
    this._integralFbZ = 0.0;
    this._kp = 1.0;
    this._ki = 0.0;
  }

  void updateWithMag(double ax, double ay, double az, double gx, double gy,
      double gz, double mx, double my, double mz) {
    var recipNorm;
    var q0q0, q0q1, q0q2, q0q3, q1q1, q1q2, q1q3, q2q2, q2q3, q3q3;
    var hx, hy, bx, bz;
    var halfvx, halfvy, halfvz, halfwx, halfwy, halfwz;
    var halfex, halfey, halfez;

    double q0 = this._qW;
    double q1 = this._qX;
    double q2 = this._qY;
    double q3 = this._qZ;

    double recipSampleFreq = 1.0 / _sampleFrequency;

    if (mx == 0 && my == 0 && mz == 0) {
      update(gx, gy, gz, ax, ay, az);
      return;
    }

    if (ax != 0 && ay != 0 && az != 0) {
      // Normalise accelerometer measurement
      recipNorm = pow((ax * ax + ay * ay + az * az), -0.5);
      ax *= recipNorm;
      ay *= recipNorm;
      az *= recipNorm;

      // Normalise magnetometer measurement
      recipNorm = pow((mx * mx + my * my + mz * mz), -0.5);
      mx *= recipNorm;
      my *= recipNorm;
      mz *= recipNorm;

      // Auxiliary variables to repeated arithmetic
      q0q0 = q0 * q0;
      q0q1 = q0 * q1;
      q0q2 = q0 * q2;
      q0q3 = q0 * q3;
      q1q1 = q1 * q1;
      q1q2 = q1 * q2;
      q1q3 = q1 * q3;
      q2q2 = q2 * q2;
      q2q3 = q2 * q3;
      q3q3 = q3 * q3;

      // Reference direction of Earth's magnetic field
      hx = 2.0 *
          (mx * (0.5 - q2q2 - q3q3) + my * (q1q2 - q0q3) + mz * (q1q3 + q0q2));
      hy = 2.0 *
          (mx * (q1q2 + q0q3) + my * (0.5 - q1q1 - q3q3) + mz * (q2q3 - q0q1));
      bx = sqrt(hx * hx + hy * hy);
      bz = 2.0 *
          (mx * (q1q3 - q0q2) + my * (q2q3 + q0q1) + mz * (0.5 - q1q1 - q2q2));

      // Estimated direction of gravity and magnetic field
      halfvx = q1q3 - q0q2;
      halfvy = q0q1 + q2q3;
      halfvz = q0q0 - 0.5 + q3q3;
      halfwx = bx * (0.5 - q2q2 - q3q3) + bz * (q1q3 - q0q2);
      halfwy = bx * (q1q2 - q0q3) + bz * (q0q1 + q2q3);
      halfwz = bx * (q0q2 + q1q3) + bz * (0.5 - q1q1 - q2q2);

      // Error is sum of cross product between estimated direction and measured direction of field vectors
      halfex = ay * halfvz - az * halfvy + (my * halfwz - mz * halfwy);
      halfey = az * halfvx - ax * halfvz + (mz * halfwx - mx * halfwz);
      halfez = ax * halfvy - ay * halfvx + (mx * halfwy - my * halfwx);

      // Compute and apply integral feedback if enabled
      if (_ki > 0.0) {
        _integralFbX +=
            _ki * halfex * recipSampleFreq; // integral error scaled by Ki
        _integralFbY += _ki * halfey * recipSampleFreq;
        _integralFbZ += _ki * halfez * recipSampleFreq;
        gx += _integralFbX; // apply integral feedback
        gy += _integralFbY;
        gz += _integralFbZ;
      } else {
        _integralFbX = 0.0; // prevent integral windup
        _integralFbY = 0.0;
        _integralFbZ = 0.0;
      }

      // Apply proportional feedback
      gx += _kp * halfex;
      gy += _kp * halfey;
      gz += _kp * halfez;
    }

    // Integrate rate of change of quaternion
    gx *= 0.5 * recipSampleFreq; // pre-multiply common factors
    gy *= 0.5 * recipSampleFreq;
    gz *= 0.5 * recipSampleFreq;
    double qa = q0;
    double qb = q1;
    double qc = q2;
    q0 += -qb * gx - qc * gy - q3 * gz;
    q1 += qa * gx + qc * gz - q3 * gy;
    q2 += qa * gy - qb * gz + q3 * gx;
    q3 += qa * gz + qb * gy - qc * gx;

    // Normalise quaternion
    recipNorm = pow((q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3), -0.5);
    q0 *= recipNorm;
    q1 *= recipNorm;
    q2 *= recipNorm;
    q3 *= recipNorm;

    this._qW = q0;
    this._qX = q1;
    this._qY = q2;
    this._qZ = q3;
  }

  void update(
      double ax, double ay, double az, double gx, double gy, double gz) {
    double q1 = this._qW;
    double q2 = this._qX;
    double q3 = this._qY;
    double q4 = this._qZ;

    double norm;
    double vx, vy, vz;
    double ex, ey, ez;
    double pa, pb, pc;

    // Convert gyroscope degrees/sec to radians/sec, deg2rad
    // PI = 3.141592653589793
    // (PI / 180) = 0.0174533
    gx *= 0.0174533;
    gy *= 0.0174533;
    gz *= 0.0174533;

    // Compute feedback only if accelerometer measurement valid
    // (avoids NaN in accelerometer normalisation)
    if ((!((ax == 0.0) && (ay == 0.0) && (az == 0.0)))) {
      // Normalise accelerometer measurement
      norm = 1.0 / sqrt(ax * ax + ay * ay + az * az);
      ax *= norm;
      ay *= norm;
      az *= norm;

      // Estimated direction of gravity
      vx = 2.0 * (q2 * q4 - q1 * q3);
      vy = 2.0 * (q1 * q2 + q3 * q4);
      vz = q1 * q1 - q2 * q2 - q3 * q3 + q4 * q4;

      // Error is cross product between estimated
      // direction and measured direction of gravity
      ex = (ay * vz - az * vy);
      ey = (az * vx - ax * vz);
      ez = (ax * vy - ay * vx);

      if (this._ki > 0.0) {
        this._integralFbX += ex; // accumulate integral error
        this._integralFbY += ey;
        this._integralFbZ += ez;
      } else {
        this._integralFbX = 0.0; // prevent integral wind up
        this._integralFbY = 0.0;
        this._integralFbZ = 0.0;
      }

      // Apply feedback terms
      gx += this._kp * ex + this._ki * this._integralFbX;
      gy += this._kp * ey + this._ki * this._integralFbY;
      gz += this._kp * ez + this._ki * this._integralFbZ;
    }

    // Integrate rate of change of quaternion
    gx *= (0.5 * this._sampleFrequency); // pre-multiply common factors
    gy *= (0.5 * this._sampleFrequency);
    gz *= (0.5 * this._sampleFrequency);
    pa = q2;
    pb = q3;
    pc = q4;
    q1 = q1 + (-q2 * gx - q3 * gy - q4 * gz); // create quaternion
    q2 = pa + (q1 * gx + pb * gz - pc * gy);
    q3 = pb + (q1 * gy - pa * gz + pc * gx);
    q4 = pc + (q1 * gz + pa * gy - pb * gx);

    // Normalise _quaternion
    norm = 1.0 / sqrt(q1 * q1 + q2 * q2 + q3 * q3 + q4 * q4);

    this._qW = q1 * norm;
    this._qX = q2 * norm;
    this._qY = q3 * norm;
    this._qZ = q4 * norm;
  }
}
