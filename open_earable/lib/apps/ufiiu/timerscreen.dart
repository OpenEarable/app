import 'package:flutter/material.dart';
import 'package:open_earable/apps/ufiiu/movementTracker.dart';
import 'package:open_earable/apps/ufiiu/sensor_datatypes.dart';

import 'interact.dart';

/// TimerScreen - Main screen for the movment timer interaction.
class TimerScreen extends StatefulWidget {
  final Interact interact;
  TimerScreen(this.interact);
  @override
  State<StatefulWidget> createState() => TimerScreenState(interact);
}


/// State for the movement Timer Interaction
class TimerScreenState extends State<TimerScreen> {

  //Interaction class
  final Interact _interact;

  //Movement & timer logic
  late final MovementTracker _movementTracker;

  //Input Controller
  final TextEditingController _controller = TextEditingController();

  //Display Data
  SensorDataType? _sensorData = NullData();

  //Constructor
  TimerScreenState(this._interact) {
    this._movementTracker = MovementTracker(_interact);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Timer App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image Source
            Image.network(
              'https://cdn-icons-png.flaticon.com/512/198/198155.png',
              width: 150,
              height: 150,
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
                ),
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
    );
  }
}