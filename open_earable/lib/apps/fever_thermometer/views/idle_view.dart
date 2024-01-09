import 'package:flutter/material.dart';

/// Idle view of the Fever Thermometer app.
class IdleView extends StatefulWidget {
  final VoidCallback? _measureTemp;
  final VoidCallback? _setReference;
  final bool _referenceSet;

  IdleView(this._measureTemp, this._setReference, this._referenceSet);

  @override
  State<IdleView> createState() =>
      _IdleViewState(_measureTemp, _setReference, _referenceSet);
}

class _IdleViewState extends State<IdleView> {
  final VoidCallback? _measureTemp;
  final VoidCallback? _setReference;
  bool _referenceSet;

  _IdleViewState(this._measureTemp, this._setReference, this._referenceSet);

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(children: [
            ElevatedButton(
                onPressed: () {
                  _setReference!();
                },
                child: Container(
                    child: _referenceSet
                        ? Text("Set reference again",
                            style: TextStyle(fontSize: 20))
                        : Text("Set reference",
                            style: TextStyle(fontSize: 20)))),
            Container(child: _referenceSet ? Text("Reference is set") : null)
          ]),
          Container(),
          Column(children: [
            ElevatedButton(
              onPressed: () {
                _measureTemp!();
              },
              child: Text("Measure temperature",
                  style: TextStyle(
                      fontSize: 20,
                      color: _referenceSet
                          ? Color(0xFFFFFFFF)
                          : Color(0x41810000))),
            ),
            Container(
                child: (_referenceSet) ? null : Text("set reference first")),
          ])
        ]);
  }
}
