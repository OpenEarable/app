import 'package:flutter/material.dart';
import 'package:open_earable/apps/fever_thermometer/settings.dart';

/// This view is used to set the real and measured reference temperature.
class ReferencingView extends StatefulWidget {
  final Settings _settings;
  final VoidCallback? _finishSensing;
  final VoidCallback? _referenceSet;

  ReferencingView(this._settings, this._finishSensing, this._referenceSet);

  @override
  State<ReferencingView> createState() =>
      _ReferencingViewState(_settings, _finishSensing, _referenceSet);
}

class _ReferencingViewState extends State<ReferencingView> {
  final Settings _settings;
  final VoidCallback? _finishSensing;
  final VoidCallback? _referenceSet;

  List<String> options = [];
  late String _selectedValue;

  _ReferencingViewState(
      this._settings, this._finishSensing, this._referenceSet);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
            onPressed: _finishSensing, child: Text("Set Current Value")),
        Container(
          child: (_settings.getReferenceMeasuredTemperature() != null)
              ? Text("Measured Temperature: " +
                  _settings
                      .getReferenceMeasuredTemperature()
                      .toStringAsFixed(2) +
                  "°C")
              : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(),
            Text("Set real Temperature: "),
            Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: DropdownButton<String>(
                  dropdownColor: Colors.white,
                  alignment: Alignment.centerRight,
                  value: _selectedValue,
                  onChanged: (
                    String? newValue,
                  ) {
                    setState(() {
                      _selectedValue = newValue!;
                    });
                  },
                  items: options.map((String value) {
                    return DropdownMenuItem<String>(
                      alignment: Alignment.centerRight,
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(color: Colors.black),
                        textAlign: TextAlign.end,
                      ),
                    );
                  }).toList(),
                  underline: Container(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Colors.black,
                  ),
                )),
            Container(),
          ],
        ),
        ElevatedButton(
            onPressed: () {
              setReferenceRealTemp(_selectedValue);
            },
            child: Text("Set actual Temperature")),
      ],
    );
  }

  @override
  void initState() {
    _settings.setReferenceMeasuredTemperature(null);
    _settings.setReferenceRealTemperature(null);
    super.initState();
    for (double i = 32.0; i <= 42.0; i += 0.1) {
      options.add(i.toStringAsFixed(1));
    }
    _selectedValue = options[(options.length / 2).round()];
  }

  /// Sets the reference real temperature.
  setReferenceRealTemp(String temp) {
    _settings.setReferenceRealTemperature(double.parse(temp));
    _referenceSet!();
  }
}
