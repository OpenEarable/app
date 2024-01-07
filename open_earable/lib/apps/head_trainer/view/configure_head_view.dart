import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/head_trainer/logic/orientation_value_updater.dart';
import 'package:open_earable/apps/head_trainer/model/orientation_value.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import '../widget/button.dart';
import '../widget/text_input.dart';

class ConfigureHeadView extends StatefulWidget {
  const ConfigureHeadView({
    required this.openEarable,
    required this.orientationValueUpdater,
  });

  final OpenEarable openEarable;
  final OrientationValueUpdater orientationValueUpdater;

  @override
  State<ConfigureHeadView> createState() => _ConfigureHeadViewState(
      this.openEarable, orientationValueUpdater);
}

class _ConfigureHeadViewState extends State<ConfigureHeadView> {

  final OpenEarable _openEarable;
  final OrientationValueUpdater _oriValueUpdater;

  _ConfigureHeadViewState(this._openEarable, this._oriValueUpdater);

  OrientationValue _oriValue = OrientationValue();
  double _yawDrift = 0.0;

  StreamSubscription? _streamSubscription;
  
  _onSetZero() {
    setState(() {
      _oriValueUpdater.valueOffset = _oriValue.getNegativeAsOffset();
    });
  }

  _setYawDrift(double yawDrift) {
    setState(() {
      _yawDrift = yawDrift;
      _oriValueUpdater.yawDrift = yawDrift;
    });
  }

  @override
  void initState() {
    super.initState();

    _yawDrift = _oriValueUpdater.yawDrift;
    _streamSubscription = _oriValueUpdater.subscribe().listen((value) {
      setState(() {
        _oriValue = value;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();

    _streamSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text("Configure Head Trainer"),
          actions: [],
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              _buildStatusCard(),
              _buildOrientationCard(_oriValue),
              _buildYawDriftCard(),
            ],
          ),
        ),
    );
  }

  Widget _buildStatusCard() {
    bool status = _openEarable.bleManager.connected;

    return Card(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "OpenEarable Status",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(status ? "Connected" : "Disconnected")
          ],
        ),
      ),
    );
  }

  Widget _buildOrientationCard(OrientationValue value) {
    return Card(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  "Orientation",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Column(
                children: [
                  _buildValueRow("Roll", value.getWithOffset().roll),
                  _buildValueRow("Pitch", value.getWithOffset().pitch),
                  _buildValueRow("Yaw", value.getWithOffset().yaw)
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Button(
                    text: "Calibrate Zero Position",
                    onPressed: () => {
                      _onSetZero()
                    },
                  ),
                ),
              ),
            ],
          )
      ),
    );
  }

  Widget _buildValueRow(String name, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: TextStyle(fontSize: 16),
        ),
        Text(
          value.toStringAsFixed(3),
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildYawDriftCard() {
    return Card(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                "Counteract Yaw Drift",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Yaw Drift"),
                      Text(
                        "Number that is added over time to counteract yaw drift",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    ),
                  ],
                )),
                SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: TextInput(
                    initialValue: _yawDrift.toString(),
                    hintText: "Yaw Drift",
                    onChanged: (value) {
                      _setYawDrift(double.parse(value));
                      },
                    keyboardType: TextInputType.number,
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

}
