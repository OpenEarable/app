import 'package:flutter/material.dart';
import 'package:open_earable/apps/earable_weather/config.dart';
import 'package:open_earable/apps/earable_weather/models/weather-forecast-model.dart';
import 'package:open_earable/apps/earable_weather/models/weather-model.dart';
import 'package:open_earable/apps/earable_weather/services/weather-service.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:lottie/lottie.dart';
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

  bool _isHorizontalView = true;

  // API Key
  final _weatherService = WeatherService(Config.openWeatherApiKey);
  Weather? _weather;
  WeatherForecast? _weatherForecast;

  _WeatherScreenState(this._openEarable);

  @override
  void initState() {
    super.initState();

    _fetchWeather();
    _fetchForecast();

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

  // Fetch weather
  void _fetchWeather() async {
    // Get the current city
    String cityName = await _weatherService.getCurrentCity();

    // Get weather for city
    try {
      final weather = await _weatherService.getWeather(cityName);
      setState(() {
        _weather = weather;
      });
    } catch(e) {
      print(e);
    }
  }

  void _fetchForecast() async {
    String cityName = await _weatherService.getCurrentCity();

    try {
      final weatherForecast = await _weatherService.getForecast(cityName);
      setState(() {
        _weatherForecast = weatherForecast;
      });
    } catch(e) {
      print(e);
    }
  }

  String _getCityBySearch() {
    return "";
  }

  // Weather animations
  String getWeatherAnimation(String? mainCondition) {
    if (mainCondition == null) {
      return 'lib/apps/earable_weather/assets/sunny.json'; 
    }

    switch(mainCondition.toLowerCase()) {
      case 'clouds':
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
        return 'lib/apps/earable_weather/assets/cloudy.json';
      case 'fog':
        return 'lib/apps/earable_weather/assets/foggy.json';
      case 'snow':
        return 'lib/apps/earable_weather/assets/snowy.json';
      case 'rain':
      case 'drizzle':
      case 'shower rain':
        return 'lib/apps/earable_weather/assets/rainy.json';
      case 'thunderstorm':
        return 'lib/apps/earable_weather/assets/thunder.json';
      case 'clear':
      default:
        return 'lib/apps/earable_weather/assets/sunny.json';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Earable Weather'),
        actions: [
          IconButton(
            icon: Icon(_isHorizontalView ? Icons.view_agenda : Icons.view_carousel),
            onPressed: () {
              setState(() {
                _isHorizontalView = !_isHorizontalView;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(  // Added SingleChildScrollView for scrolling
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // City name
              Text(_weather?.cityName ?? "Loading City..."),
              // Animation
              Lottie.asset(getWeatherAnimation(_weather?.mainCondition), height: 200), // Adjusted height for visibility
              // Temperature
              Text('${_weather?.temperature.round()}°C'),
              // Weather Condition
              Text(_weather?.mainCondition ?? ""),
              SizedBox(height: 20), // Adds a bit of spacing

              // Display forecast
              _displayForecast(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _displayForecast() {
    List<Widget> cards = _weatherForecast!.dailyForecast.map((Weather weather) {
      return Card(
        child: Column(
          children: [
            Lottie.asset(getWeatherAnimation(weather.mainCondition), width: 100, height: 100),
            Text('${weather.temperature.round()}°C'),
            Text(weather.mainCondition),
          ],
        ),
      );
    }).toList();

    if (_isHorizontalView) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: cards,
        ),
      );
    } else {
      return Column(
        children: cards.map((card) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: SizedBox(width: double.infinity, height: 150, child: card),
        )).toList(),
      );
    }
  }


  @override
  void dispose() {
    _barometerSubscription?.cancel();  
    super.dispose(); 
  }
}