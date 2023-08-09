import 'package:flutter/material.dart';

class BLEPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connect OpenEarable'),
      ),
      body: Center(
        child: Text('BLE scan/connect functionality goes here'),
      ),
    );
  }
}