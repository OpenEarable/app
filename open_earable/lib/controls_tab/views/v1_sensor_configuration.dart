import 'package:flutter/material.dart';
import 'package:open_earable/shared/dynamic_value_picker.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import '../models/open_earable_settings.dart';

class V1SensorConfigurationCard extends StatelessWidget {
  const V1SensorConfigurationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothController>(
      builder: (context, bleController, child) {
        return _InternalV1SensorConfigurationCard(
          openEarable: bleController.currentOpenEarable,
          connected: bleController.currentOpenEarable.bleManager.connected,
        );
      },
    );
  }
}

class _InternalV1SensorConfigurationCard extends StatefulWidget {
  final OpenEarable openEarable;
  final bool connected;

  const _InternalV1SensorConfigurationCard({
    required this.openEarable,
    required this.connected,
  });

  @override
  State<_InternalV1SensorConfigurationCard> createState() =>
      _InternalV1SensorConfigurationCardState();
}

class _InternalV1SensorConfigurationCardState
    extends State<_InternalV1SensorConfigurationCard> {
  Color _getCheckboxColor(Set<WidgetState> states) {
    const Set<WidgetState> interactiveStates = <WidgetState>{
      WidgetState.pressed,
      WidgetState.hovered,
      WidgetState.focused,
      WidgetState.selected,
    };
    if (states.any(interactiveStates.contains)) {
      return Theme.of(context).colorScheme.secondary;
    }
    return Theme.of(context).colorScheme.primary;
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Invalid sampling rates'),
          content: Text(
            'Please ensure that sampling rates of IMU and Barometer are not greater than 30 Hz',
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _writeSensorConfigs() async {
    double? imuSamplingRate =
        double.tryParse(OpenEarableSettings().selectedImuOption);
    double? barometerSamplingRate =
        double.tryParse(OpenEarableSettings().selectedBarometerOption);
    double? microphoneSamplingRate =
        double.tryParse(OpenEarableSettings().selectedMicrophoneOption);
    if (imuSamplingRate == null ||
        barometerSamplingRate == null ||
        microphoneSamplingRate == null ||
        imuSamplingRate > 30 ||
        imuSamplingRate < 0 ||
        barometerSamplingRate > 30 ||
        barometerSamplingRate < 0) {
      _showErrorDialog(context);
    }
    OpenEarableSensorConfig imuConfig = OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate:
          OpenEarableSettings().imuSettingSelected ? imuSamplingRate! : 0,
      latency: 0,
    );
    OpenEarableSensorConfig barometerConfig = OpenEarableSensorConfig(
      sensorId: 1,
      samplingRate: OpenEarableSettings().barometerSettingSelected
          ? barometerSamplingRate!
          : 0,
      latency: 0,
    );
    OpenEarableSensorConfig microphoneConfig = OpenEarableSensorConfig(
      sensorId: 2,
      samplingRate: OpenEarableSettings().microphoneSettingSelected
          ? microphoneSamplingRate!
          : 0,
      latency: 0,
    );
    await widget.openEarable.sensorManager.writeSensorConfig(imuConfig);
    await widget.openEarable.sensorManager.writeSensorConfig(barometerConfig);
    await widget.openEarable.sensorManager.writeSensorConfig(microphoneConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Card(
        //Audio Player Card
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sensor Configuration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _sensorConfigurationRow(
                  "IMU",
                  OpenEarableSettings().imuAndBarometerOptions,
                  OpenEarableSettings().imuSettingSelected,
                  OpenEarableSettings().selectedImuOption, (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    OpenEarableSettings().imuSettingSelected = newValue;
                  });
                }
              }, (String newValue) {
                setState(() {
                  OpenEarableSettings().selectedImuOption = newValue;
                });
              }),
              _sensorConfigurationRow(
                  "Barometer",
                  OpenEarableSettings().imuAndBarometerOptions,
                  OpenEarableSettings().barometerSettingSelected,
                  OpenEarableSettings().selectedBarometerOption,
                  (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    OpenEarableSettings().barometerSettingSelected = newValue;
                  });
                }
              }, (String newValue) {
                setState(() {
                  OpenEarableSettings().selectedBarometerOption = newValue;
                });
              }),
              _sensorConfigurationRow(
                  "Microphone",
                  OpenEarableSettings().microphoneOptions,
                  OpenEarableSettings().microphoneSettingSelected,
                  OpenEarableSettings().selectedMicrophoneOption,
                  (bool? newValue) {
                setState(() {
                  OpenEarableSettings().microphoneSettingSelected = newValue!;
                });
              }, (String newValue) {
                setState(() {
                  OpenEarableSettings().selectedMicrophoneOption = newValue;
                });
              }),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 37,
                      child: ElevatedButton(
                        onPressed:
                            widget.connected
                                ? _writeSensorConfigs
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              widget.connected
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.grey,
                          foregroundColor: Colors.black,
                          enableFeedback:
                              widget.connected,
                        ),
                        child: Text("Set Configuration"),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sensorConfigurationRow(
    String sensorName,
    List<String> options,
    bool settingSelected,
    String currentValue,
    Function(bool?) changeBool,
    Function(String) changeSelection,
  ) {
    return Row(
      children: [
        Checkbox(
          checkColor: Theme.of(context).colorScheme.primary,
          fillColor: WidgetStateProperty.resolveWith(_getCheckboxColor),
          value: settingSelected,
          onChanged: widget.connected
              ? changeBool
              : null,
        ),
        Text(
          sensorName,
          style: TextStyle(
            color: Color.fromRGBO(168, 168, 172, 1.0),
          ),
        ),
        Spacer(),
        Container(
          decoration: BoxDecoration(
            color: widget.connected
                ? Colors.white
                : Colors.grey,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: SizedBox(
            width: 100,
            height: 37,
            child: Container(
              alignment: Alignment.centerRight,
              child: DynamicValuePicker(
                context,
                options,
                currentValue,
                changeSelection,
                widget.connected,
                false,
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Text("Hz", style: TextStyle(color: Color.fromRGBO(168, 168, 172, 1.0))),
      ],
    );
  }
}
