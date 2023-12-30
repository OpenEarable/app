import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter/cupertino.dart';
import '../../ble.dart';

class ConnectCard extends StatelessWidget {
  final OpenEarable _openEarable;
  final int _earableSOC;

  ConnectCard(this._openEarable, this._earableSOC);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Card(
        color: Platform.isIOS
            ? CupertinoTheme.of(context).primaryContrastingColor
            : Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              _getEarableInfo(),
              SizedBox(height: 8),
              _getConnectButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getEarableInfo() {
    return Row(
      children: [
        if (_openEarable.bleManager.connected)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_openEarable.bleManager.connectedDevice?.name ?? ""} (${_earableSOC}%)",
                style: TextStyle(
                  color: Color.fromRGBO(168, 168, 172, 1.0),
                  fontSize: 15.0,
                ),
              ),
              Text(
                "Firmware ${_openEarable.deviceFirmwareVersion ?? "0.0.0"}",
                style: TextStyle(
                  color: Color.fromRGBO(168, 168, 172, 1.0),
                  fontSize: 15.0,
                ),
              ),
            ],
          )
        else
          Text(
            "OpenEarable not connected.",
            style: TextStyle(
              color: Color.fromRGBO(168, 168, 172, 1.0),
              fontSize: 15.0,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _getConnectButton(BuildContext context) {
    return Visibility(
      visible: !_openEarable.bleManager.connected,
      child: Container(
          height: 37,
          width: double.infinity,
          child: !Platform.isIOS
              ? ElevatedButton(
                  onPressed: () => _connectButtonAction(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_openEarable.bleManager.connected
                        ? Color(0xff77F2A1)
                        : Color(0xfff27777),
                    foregroundColor: Colors.black,
                  ),
                  child: Text("Connect"),
                )
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: CupertinoTheme.of(context).primaryColor,
                  child: Text("Connect"),
                  onPressed: () => _connectButtonAction(context))),
    );
  }

  _connectButtonAction(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => BLEPage(_openEarable)));
  }
}
