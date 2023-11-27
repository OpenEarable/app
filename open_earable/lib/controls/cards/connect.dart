import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import '../../ble.dart';

class ConnectCard extends StatelessWidget {
  final OpenEarable _openEarable;
  final int earableSOC;

  ConnectCard(this._openEarable, this.earableSOC);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Card(
        color: Color(0xff161618),
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
              SizedBox(height: 5),
              earableInfo(),
              connectButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget earableInfo() {
    return Row(
      children: [
        if (_openEarable.bleManager.connected)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_openEarable.bleManager.connectedDevice?.name ?? ""} (${earableSOC}%)",
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

  Widget connectButton(BuildContext context) {
    return Visibility(
      visible: !_openEarable.bleManager.connected,
      child: Column(
        children: [
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 37.0,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => BLEPage(_openEarable)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_openEarable.bleManager.connected
                          ? Color(0xff77F2A1)
                          : Color(0xfff27777),
                      foregroundColor: Colors.black,
                    ),
                    child: Text("Connect"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
