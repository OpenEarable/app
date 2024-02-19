/// Sensor Data is the super data typ for possible datatypes used for the movement tracker.
/// It reads the JSON of the Earable and provides the getters for accessing the data.
class SensorDataType {
  //Data map
  Map<dynamic, dynamic> data;

  //Constructor
  SensorDataType(this.data);

  //Getters for the data
  double get x => data["X"];
  double get y => data["Y"];
  double get z => data["Z"];

  //Units for the given data.
  Map<String, String> get units => data["units"];
}

/// Acceleration-sensor data.
class Acceleration extends SensorDataType {
  Acceleration(Map<dynamic, dynamic> data) : super(data["ACC"]);
}

/// Gyroscope-sensor data.
class Gyroscope extends SensorDataType {
  Gyroscope(Map<dynamic, dynamic> data) : super(data["GYRO"]);
}

/// EulerAngles-sensor data.
class EulerAngles extends SensorDataType {
  EulerAngles(Map<dynamic, dynamic> data) : super(data["EULER"]);
}

/// Placeholder data without any information in case no sensor data is available.
class NullData extends SensorDataType {
  NullData() : super({"X": 0.0, "Y": 0.0, "Z": 0.0});
}