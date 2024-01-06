import 'package:flutter/material.dart';
import 'package:open_earable/apps/earable_weather/config.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'dart:async';

class WeatherPage extends StatefulWidget {
  final OpenEarable _openEarable;
  WeatherPage(this._openEarable);

  @override
  _WeatherScreenState createState() => _WeatherScreenState(_openEarable);
}

class _WeatherScreenState extends State<WeatherPage> {
  final OpenEarable _openEarable;

  _WeatherScreenState(this._openEarable);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Text('Earbale Weather'),
        ),
    );
  }
}