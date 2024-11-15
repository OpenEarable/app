import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/shared/dynamic_value_picker.dart';
import '../../models/open_earable_settings_v2.dart';
import 'package:open_earable/ble/ble_controller.dart';

class SensorControlRow extends StatefulWidget {
  final String sensorName;

  const SensorControlRow(this.sensorName, {super.key});

  @override
  State<SensorControlRow> createState() => _SensorControlRow();
}

class _SensorControlRow extends State<SensorControlRow> {
  @override
  Widget build(BuildContext context) {
    SensorSettings sensorSettings =
        Provider.of<SensorSettings>(context, listen: true);
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 16, 0),
      child: Row(
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Checkbox(
              checkColor: Theme.of(context).colorScheme.primary,
              fillColor: WidgetStateProperty.resolveWith(_getCheckboxColor),
              value: sensorSettings.sensorSelected,
              onChanged: Provider.of<BluetoothController>(context).connected
                  ? (value) {
                      setState(() {
                        sensorSettings.sensorSelected = value ?? false;
                      });
                    }
                  : null,
            ),
          ),
          Text(
            widget.sensorName,
            style: TextStyle(
              color: Color.fromRGBO(168, 168, 172, 1.0),
            ),
          ),
          Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Provider.of<BluetoothController>(context).connected
                  ? Colors.white
                  : Colors.grey,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: SizedBox(
              width: 80,
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
                ),
              ),
            ),
          ),
          SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              color: Provider.of<BluetoothController>(context).connected
                  ? Colors.white
                  : Colors.grey,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: SizedBox(
              width: 80,
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
                ),
              ),
            ),
          ),
          SizedBox(width: 4),
          Text(
            "Hz",
            style: TextStyle(color: Color.fromRGBO(168, 168, 172, 1.0)),
          ),
        ],
      ),
    );
  }

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
}
