import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/powernapper/movement_tracker.dart';
import 'package:open_earable/apps_tab/powernapper/sensor_datatypes.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';
import 'package:provider/provider.dart';

import 'interact.dart';

/// TimerScreen - Main screen for the movment timer interaction.
class TimerScreen extends StatefulWidget {
  final Interact interact;

  const TimerScreen(this.interact, {super.key});

  @override
  State<StatefulWidget> createState() => TimerScreenState();
}

/// State for the movement Timer Interaction
class TimerScreenState extends State<TimerScreen> {
  //Movement & timer logic
  late final MovementTracker _movementTracker;

  //Input Controller
  final TextEditingController _controller = TextEditingController();

  //Display Data
  SensorDataType? _sensorData = NullData();

  @override
  void initState() {
    super.initState();
    _movementTracker = MovementTracker(widget.interact);
  }

  @override
  void dispose() {
    super.dispose();
    _movementTracker.stop();
  }

  //Updates the text data.
  void updateText(SensorDataType sensorData) {
    setState(() {
      _sensorData = sensorData;
    });
  }

  ///Builds the main Widget
  @override
  Widget build(BuildContext context) {
    return Provider.of<BluetoothController>(context, listen: false).connected
        ? GestureDetector(
            onTap: () {
              FocusScope.of(context).requestFocus(FocusNode());
            },
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'lib/apps_tab/powernapper/assets/powernapping.png',
                      width: 150,
                      height: 150,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 20),

                    // Input for Time length
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Zeitlänge eingeben (in Minuten)',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                        style: TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Start timer button
                    ElevatedButton(
                      onPressed: () {
                        String input = _controller.text;
                        int minutes = int.tryParse(input) ?? 0;

                        _movementTracker.start(minutes, updateText);
                      },
                      child: Text('Starten'),
                    ),

                    //Data table for the live display of the sensor data.
                    DataTable(
                      columns: [
                        DataColumn(label: Text('Sensor')),
                        DataColumn(label: Text('Wert')),
                      ],
                      rows: [
                        DataRow(
                          cells: [
                            DataCell(Text('X')),
                            DataCell(Text(_sensorData!.x.toStringAsFixed(14))),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(Text('Y')),
                            DataCell(Text(_sensorData!.y.toStringAsFixed(14))),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(Text('Z')),
                            DataCell(Text(_sensorData!.z.toStringAsFixed(14))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        : EarableNotConnectedWarning();
  }
}
