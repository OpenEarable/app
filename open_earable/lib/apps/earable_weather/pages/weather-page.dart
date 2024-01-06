import 'package:flutter/material.dart';
import 'package:open_earable/apps/earable_weather/config.dart';
import 'package:open_earable/apps/earable_weather/models/weather-model.dart';
import 'package:open_earable/apps/earable_weather/services/weather-service.dart';
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

  StreamSubscription? _barometerSubscription;

  // Add state variables for sensor data
  String timestamp = "";
  String temperature = "";
  String pressure = ""; 

  // API Key
  final _weatherService = WeatherService(Config.openWeatherApiKey);
  Weather? _weather;

  _WeatherScreenState(this._openEarable);

  @override
  void initState() {
    super.initState();

    _fetchWeather();

    /*
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }*/
  }

  void _setupListeners() {
    _barometerSubscription = _openEarable.sensorManager.subscribeToSensorData(1).listen((event) {
      timestamp = event["timestamp"].toString();
      pressure = event["BARO"]["Pressure"].toString();
      temperature = event["TEMP"]["Temperature"].toString();
    });
  }

  void _fetchWeather() {
    
  }

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