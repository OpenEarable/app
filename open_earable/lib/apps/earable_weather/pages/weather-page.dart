import 'package:flutter/material.dart';
import 'package:open_earable/apps/earable_weather/config.dart';
import 'package:open_earable/apps/earable_weather/models/weather-forecast-model.dart';
import 'package:open_earable/apps/earable_weather/models/weather-model.dart';
import 'package:open_earable/apps/earable_weather/services/weather-service.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

const double EDGE_OFFSET = 100.0;

class WeatherPage extends StatefulWidget {
  final OpenEarable _openEarable;
  WeatherPage(this._openEarable);

  @override
  _WeatherScreenState createState() => _WeatherScreenState(_openEarable);
}

class _WeatherScreenState extends State<WeatherPage> {
  final OpenEarable _openEarable;

  // Add state variables for sensor data
  StreamSubscription? _barometerSubscription;
  StreamSubscription? _batteryLevelSubscription;
  int _earableBattery = 0;
  String pressure = ""; 

  bool isHorizontalView = true;
  bool playSound = true;

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

    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
  }

  void _setupListeners() {
    _barometerSubscription = _openEarable.sensorManager.subscribeToSensorData(1).listen((event) {
      pressure = event["BARO"]["Pressure"].toString();
    });

    _batteryLevelSubscription = _openEarable.sensorManager.getBatteryLevelStream().listen((batteryLevel) {
      setState(() {
        _earableBattery = batteryLevel[0].toInt();
      });
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

  Future<void> refreshWeather() async {
    try {
      _fetchWeather();
      _fetchForecast();
      //_showFeedback(true); // true for success
    } catch (e) {
      print(e); 
      //_showFeedback(false); // false for failure
    }
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
      case 'thunderstorm':
        this._notificationSound(4);
        return 'lib/apps/earable_weather/assets/thunder.json';
      case 'rain':
      case 'drizzle':
      case 'shower rain':
        return 'lib/apps/earable_weather/assets/rainy.json';
      case 'clear':
      default:
        return 'lib/apps/earable_weather/assets/sunny.json';
    }
  }

  // Should only be called if a thunderstorm is about to happen
  void _notificationSound(int id) {
    if (playSound) {
      _openEarable.audioPlayer.jingle(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Earable Weather'),
            Text('${_earableBattery}%'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isHorizontalView ? Icons.view_agenda : Icons.view_carousel),
            onPressed: () {
              setState(() {
                isHorizontalView = !isHorizontalView;
              });
            },
          ),
          // Toggle for sound
          Switch(
            value: playSound,
            onChanged: (value) {
              setState(() {
                playSound = value;
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: Colors.black,
        edgeOffset: EDGE_OFFSET,
        onRefresh: () async {
          await refreshWeather();
          return Future<void>.delayed(const Duration(seconds: 3));
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 60),
                // City name
                Text(
                  _weather?.cityName ?? "Loading City...",
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                // Current date 
                Text(
                  _weather?.longFormattedDate ?? "",
                  style: TextStyle(fontSize: 15),
                ),
                SizedBox(height: 60),
                // Animation
                Lottie.asset(getWeatherAnimation(_weather?.mainCondition), height: 200),
                SizedBox(height: 20),
                // Temperature
                Text(
                  '${_weather?.temperature.round()}°C',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                // Main condition and icon button
                Text(
                  _weather?.mainCondition ?? "",
                  style: TextStyle(fontSize: 15)
                ),
                SizedBox(height: 20),
                // Display forecast
                _displayForecast(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _displayForecast() {
    // Generate the list of cards from the weather forecast data
    List<Widget> cards = _weatherForecast!.dailyForecast.map((Weather weather) {
      return Card(
        child: Column(
          children: [
            Lottie.asset(getWeatherAnimation(weather.mainCondition), width: 100, height: 100),
            Text('${weather.temperature.round()}°C'),
            Text(weather.shortFormattedDate),
          ],
        ),
      );
    }).toList();

    // Determine the screen size
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // Conditional layout based on _isHorizontalView
    if (isHorizontalView) {
      double cardWidth = screenWidth / 5.0; // Adjust as needed for horizontal view
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: cards.map((card) => SizedBox(width: cardWidth, child: card)).toList(),
        ),
      );
    } else {
      double cardHeight = screenHeight / 12.5; 
      List<Widget> verticalCards = _weatherForecast!.dailyForecast.map((Weather weather) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            height: cardHeight,
            child: Card(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Lottie.asset(getWeatherAnimation(weather.mainCondition), fit: BoxFit.contain),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${weather.temperature.round()}°C'),
                        Text(weather.shortFormattedDate),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList();
      return Column(children: verticalCards);
    }
  }

  @override
  void dispose() { 
    super.dispose();
    _barometerSubscription?.cancel();  
    _batteryLevelSubscription?.cancel();
  }
}