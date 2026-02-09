import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ThisDeviceWearable extends Wearable
    implements SensorManager, SensorConfigurationManager {
  @override
  final List<Sensor> sensors = [];

  @override
  final List<SensorConfiguration> sensorConfigurations = [];

  @override
  Stream<Map<SensorConfiguration, SensorConfigurationValue>>
      get sensorConfigurationStream => const Stream.empty();

  ThisDeviceWearable({required super.disconnectNotifier})
      : super(name: "This Device") {
    sensors.add(MockGyroSensor());
    sensors.add(MockAccelerometer());
  }

  @override
  String get deviceId => "THIS-DEVICE-001";

  @override
  Future<void> disconnect() async {
    // nothing to do
    return Future.value();
  }

  @override
  String? getWearableIconPath({bool darkmode = false}) {
    return null;
  }
}

class MockGyroSensor extends Sensor<SensorDoubleValue> {
  MockGyroSensor()
      : super(
          sensorName: "Gyroscope",
          chartTitle: "Gyroscope",
          shortChartTitle: "Gyro",
          relatedConfigurations: [],
        );

  @override
  List<String> get axisNames => ['X', 'Y', 'Z'];

  @override
  List<String> get axisUnits => ['rad/s', 'rad/s', 'rad/s'];

  @override
  Stream<SensorDoubleValue> get sensorStream {
    return gyroscopeEventStream().map((event) {
      return SensorDoubleValue(
        values: [event.x, event.y, event.z],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
}

class MockAccelerometer extends Sensor<SensorDoubleValue> {
  MockAccelerometer()
      : super(
          sensorName: "Accelerometer",
          chartTitle: "Accelerometer",
          shortChartTitle: "Accel",
          relatedConfigurations: [
            MockConfigurableSensorConfiguration(
                name: "Sensor Rate",
                availableOptions: {
                  StreamSensorConfigOption(),
                },
                values: [
                  MockConfigurableSensorConfigurationValue(
                      key: "30Hz",
                      options: {
                        StreamSensorConfigOption(),
                      },),
                ],),
          ],
        );

  @override
  List<String> get axisNames => ['X', 'Y', 'Z'];

  @override
  List<String> get axisUnits => ['m/s²', 'm/s²', 'm/s²'];

  @override
  Stream<SensorDoubleValue> get sensorStream {
    return accelerometerEventStream().map((event) {
      return SensorDoubleValue(
        values: [event.x, event.y, event.z],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
}

class MockConfigurableSensorConfiguration
    extends ConfigurableSensorConfiguration<
        MockConfigurableSensorConfigurationValue> {
  MockConfigurableSensorConfiguration({
    required super.name,
    required super.values,
    super.availableOptions,
  });

  @override
  void setConfiguration(
      MockConfigurableSensorConfigurationValue configuration,) {
    // no-op
  }
}

class MockConfigurableSensorConfigurationValue
    extends ConfigurableSensorConfigurationValue {
  MockConfigurableSensorConfigurationValue({
    required super.key,
    super.options,
  });

  @override
  MockConfigurableSensorConfigurationValue withoutOptions() {
    return MockConfigurableSensorConfigurationValue(key: key);
  }
}
