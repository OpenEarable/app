import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/shared/dynamic_value_picker.dart';
import '../../models/open_earable_settings_v2.dart';
import 'dart:io';
import 'package:open_earable/ble/ble_controller.dart';

class SensorControlRow extends StatefulWidget {
  final String _sensorName;
  SensorControlRow(this._sensorName);
  @override
  _SensorControlRow createState() => _SensorControlRow(_sensorName);
}

class _SensorControlRow extends State<SensorControlRow> {
  String _sensorName;
  _SensorControlRow(this._sensorName);
  @override
  Widget build(BuildContext context) {
    SensorSettings sensorSettings =
        Provider.of<SensorSettings>(context, listen: true);
    return Row(
      children: [
        Platform.isIOS
            ? CupertinoCheckbox(
                value: sensorSettings.sensorSelected,
                onChanged: Provider.of<BluetoothController>(context).connected
                    ? (value) {
                        setState(() {
                          sensorSettings.sensorSelected = value ?? false;
                        });
                      }
                    : null,
                activeColor: sensorSettings.sensorSelected
                    ? CupertinoTheme.of(context).primaryColor
                    : CupertinoTheme.of(context).primaryContrastingColor,
                checkColor: CupertinoTheme.of(context).primaryContrastingColor,
              )
            : Checkbox(
                checkColor: Theme.of(context).colorScheme.primary,
                fillColor: MaterialStateProperty.resolveWith(_getCheckboxColor),
                value: sensorSettings.sensorSelected,
                onChanged: Provider.of<BluetoothController>(context).connected
                    ? (value) {
                        setState(() {
                          sensorSettings.sensorSelected = value ?? false;
                        });
                      }
                    : null,
              ),
        Text(
          _sensorName,
          style: TextStyle(
            color: Color.fromRGBO(168, 168, 172, 1.0),
          ),
        ),
        Spacer(),
        Container(
            decoration: BoxDecoration(
              color: Provider.of<BluetoothController>(context).connected
                  ? Colors.white
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: SizedBox(
                width: 70,
                height: 37,
                child: Container(
                    alignment: Alignment.centerRight,
                    child: DynamicValuePicker(
                      context,
                      sensorSettings.frequencyOptionsBLE,
                      sensorSettings.selectedOptionBLE,
                      (newValue) {
                        sensorSettings.updateSelectedBLEOption(newValue);
                      },
                      Provider.of<BluetoothController>(context).connected,
                      sensorSettings.isFakeDisabledBLE,
                    )))),
        SizedBox(width: 8),
        Container(
            decoration: BoxDecoration(
              color: Provider.of<BluetoothController>(context).connected
                  ? Colors.white
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: SizedBox(
                width: 70,
                height: 37,
                child: Container(
                    alignment: Alignment.centerRight,
                    child: DynamicValuePicker(
                      context,
                      sensorSettings.frequencyOptionsSD,
                      sensorSettings.selectedOptionSD,
                      (newValue) {
                        sensorSettings.updateSelectedSDOption(newValue);
                      },
                      Provider.of<BluetoothController>(context).connected,
                      sensorSettings.isFakeDisabledSD,
                    )))),
        SizedBox(width: 8),
        Text("Hz", style: TextStyle(color: Color.fromRGBO(168, 168, 172, 1.0))),
      ],
    );
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
}
