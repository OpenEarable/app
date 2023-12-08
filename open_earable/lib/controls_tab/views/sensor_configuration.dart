import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import '../models/open_earable_settings.dart';

class SensorConfigurationCard extends StatefulWidget {
  final OpenEarable _openEarable;
  SensorConfigurationCard(this._openEarable);

  @override
  _SensorConfigurationCardState createState() =>
      _SensorConfigurationCardState(_openEarable);
}

class _SensorConfigurationCardState extends State<SensorConfigurationCard> {
  final OpenEarable _openEarable;
  _SensorConfigurationCardState(this._openEarable);

  void initState() {
    super.initState();
  }

  Color _getCheckboxColor(Set<MaterialState> states) {
    const Set<MaterialState> interactiveStates = <MaterialState>{
      MaterialState.pressed,
      MaterialState.hovered,
      MaterialState.focused,
      MaterialState.selected,
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
              'Please ensure that sampling rates of IMU and Barometer are not greater than 30 Hz'),
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
        latency: 0);
    OpenEarableSensorConfig barometerConfig = OpenEarableSensorConfig(
        sensorId: 1,
        samplingRate: OpenEarableSettings().barometerSettingSelected
            ? barometerSamplingRate!
            : 0,
        latency: 0);
    OpenEarableSensorConfig microphoneConfig = OpenEarableSensorConfig(
        sensorId: 2,
        samplingRate: OpenEarableSettings().microphoneSettingSelected
            ? microphoneSamplingRate!
            : 0,
        latency: 0);
    await _openEarable.sensorManager.writeSensorConfig(imuConfig);
    await _openEarable.sensorManager.writeSensorConfig(barometerConfig);
    await _openEarable.sensorManager.writeSensorConfig(microphoneConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Card(
        //Audio Player Card
        color: Color(0xff161618),
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
                OpenEarableSettings().selectedImuOption = newValue;
              }),
              _sensorConfigurationRow(
                  "Barometer",
                  OpenEarableSettings().imuAndBarometerOptions,
                  OpenEarableSettings().barometerSettingSelected,
                  OpenEarableSettings().selectedBarometerOption,
                  (bool? newValue) {
                if (newValue != null) {
                  setState(() {
                    print("SELECTED $newValue");
                    OpenEarableSettings().barometerSettingSelected = newValue;
                    print(OpenEarableSettings().barometerSettingSelected);
                  });
                }
              }, (String newValue) {
                OpenEarableSettings().selectedBarometerOption = newValue;
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
                OpenEarableSettings().selectedMicrophoneOption = newValue;
              }),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 37.0,
                      child: ElevatedButton(
                        onPressed: _openEarable.bleManager.connected
                            ? _writeSensorConfigs
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _openEarable.bleManager.connected
                              ? Theme.of(context).colorScheme.secondary
                              : Colors.grey,
                          foregroundColor: Colors.black,
                          enableFeedback: _openEarable.bleManager.connected,
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
      Function(String) changeSelection) {
    return Row(
      children: [
        Checkbox(
          checkColor: Theme.of(context).colorScheme.primary,
          fillColor: MaterialStateProperty.resolveWith(_getCheckboxColor),
          value: settingSelected,
          onChanged: _openEarable.bleManager.connected ? changeBool : null,
        ),
        Text(sensorName),
        Spacer(),
        Container(
            decoration: BoxDecoration(
              color: _openEarable.bleManager.connected
                  ? Colors.white
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: SizedBox(
                height: 37,
                width: 100,
                child: Container(
                    alignment: Alignment.centerRight,
                    child: DropdownButton<String>(
                      dropdownColor: _openEarable.bleManager.connected
                          ? Colors.white
                          : Colors.grey[200],
                      alignment: Alignment.centerRight,
                      value: currentValue,
                      onChanged: (String? newValue) {
                        setState(() {
                          changeSelection(newValue!);
                          if (int.parse(newValue) != 0) {
                            changeBool(true);
                          } else {
                            changeBool(false);
                          }
                        });
                      },
                      items: options.map((String value) {
                        return DropdownMenuItem<String>(
                          alignment: Alignment.centerRight,
                          value: value,
                          child: Text(
                            value,
                            style: TextStyle(
                              color: _openEarable.bleManager.connected
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        );
                      }).toList(),
                      underline: Container(),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: _openEarable.bleManager.connected
                            ? Colors.black
                            : Colors.grey,
                      ),
                    )))),
        SizedBox(width: 8),
        Text("Hz"),
      ],
    );
  }
}
