import 'package:flutter/material.dart';
import 'package:open_earable/apps/earable_weather/config.dart';
import 'package:open_earable/apps/earable_weather/models/weather-forecast-model.dart';
import 'package:open_earable/apps/earable_weather/models/weather-model.dart';
import 'package:open_earable/apps/earable_weather/services/weather-service.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

// Constant for edge offset used in UI layout
const double EDGE_OFFSET = 100.0;

// StatefulWidget for the WeatherPage
class WeatherPage extends StatefulWidget {
  final OpenEarable _openEarable;

  // Constructor accepting an OpenEarable instance
  WeatherPage(this._openEarable);

  @override
  _WeatherScreenState createState() => _WeatherScreenState(_openEarable);
}

// State class for WeatherPage
class _WeatherScreenState extends State<WeatherPage> {
  final OpenEarable _openEarable;

  // State variables for sensor data
  StreamSubscription? _barometerSubscription;
  StreamSubscription? _batteryLevelSubscription;
  int _earableBattery = 0;
  String pressure = ""; 

  // State variables for UI control
  bool isHorizontalView = true;
  bool playSound = true;

  // Weather service instance with API key
  final _weatherService = WeatherService(Config.openWeatherApiKey);

  // Nullable variables for weather data
  Weather? _weather;
  WeatherForecast? _weatherForecast;

  // Constructor initializing with OpenEarable
  _WeatherScreenState(this._openEarable);

  @override
  void initState() {
    super.initState();

    // Fetch weather data and setup sensor listeners
    _fetchWeather();
    _fetchForecast();
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
  }

  // Setup listeners for sensor data
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

  // Fetch current weather data
  void _fetchWeather() async {
    try {
      String cityName = await _weatherService.getCurrentCity();
      final weather = await _weatherService.getWeather(cityName);
      setState(() {
        _weather = weather;
      });
    } catch(e) {
      print(e);
    }
  }

  // Fetch weather forecast data
  void _fetchForecast() async {
    try {
      String cityName = await _weatherService.getCurrentCity();
      final weatherForecast = await _weatherService.getForecast(cityName);
      setState(() {
        _weatherForecast = weatherForecast;
      });
    } catch(e) {
      print(e);
    }
  }

  // Refresh weather data (used for pull-to-refresh functionality)
  Future<void> refreshWeather() async {
    try {
      _fetchWeather();
      _fetchForecast();
    } catch (e) {
      print(e); 
    }
  }

  // Function to determine the appropriate weather animation based on the current weather condition
  String getWeatherAnimation(String? mainCondition) {
    // Default to sunny animation if no condition is provided
    if (mainCondition == null) {
      return 'lib/apps/earable_weather/assets/sunny.json'; 
    }

    // Switch statement to handle different weather conditions
    switch(mainCondition.toLowerCase()) {
      // Cloudy-related conditions
      case 'clouds':
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
        return 'lib/apps/earable_weather/assets/cloudy.json';
      // Foggy weather condition
      case 'fog':
        return 'lib/apps/earable_weather/assets/foggy.json';
      // Snowy weather condition
      case 'snow':
        return 'lib/apps/earable_weather/assets/snowy.json';
      // Thunderstorm condition
      case 'thunderstorm':
        this._notificationSound(4); // Play notification sound for thunderstorm
        return 'lib/apps/earable_weather/assets/thunder.json';
      // Rainy weather conditions
      case 'rain':
      case 'drizzle':
      case 'shower rain':
        return 'lib/apps/earable_weather/assets/rainy.json';
      // Clear weather or any other unspecified condition
      case 'clear':
      default:
        return 'lib/apps/earable_weather/assets/sunny.json';
    }
  }

  // Plays a notification sound, intended for use when a thunderstorm is detected
  void _notificationSound(int id) {
    // Check if sound play is enabled
    if (playSound) {
      _openEarable.audioPlayer.jingle(id);
    }
  }

  void _playWeatherAudio() {
    String weatherAudioFileName = "";
    _openEarable.audioPlayer.wavFile(weatherAudioFileName);
  } 

  @override
  Widget build(BuildContext context) {
    // Main widget build method for WeatherPage
    return Scaffold(
      appBar: AppBar(
        // AppBar setup
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Earable Weather'), // App title
            Text('${_earableBattery}%'), // Display battery percentage
          ],
        ),
        actions: [
          // Button to toggle view between horizontal and vertical
          IconButton(
            icon: Icon(isHorizontalView ? Icons.view_agenda : Icons.view_carousel),
            onPressed: () {
              setState(() {
                isHorizontalView = !isHorizontalView;
              });
            },
          ),
          // Switch to toggle sound on or off
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
        // RefreshIndicator for pull-down-to-refresh functionality
        color: Colors.white,
        backgroundColor: Colors.black,
        edgeOffset: EDGE_OFFSET,
        onRefresh: () async {
          await refreshWeather();
          return Future<void>.delayed(const Duration(seconds: 3));
        },
        child: _weather != null ? SafeArea(
          // Display weather information if available
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 60),
                // Display city name
                Text(
                  _weather?.cityName ?? "Loading City...",
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                // Display current date
                Text(
                  _weather?.longFormattedDate ?? "",
                  style: TextStyle(fontSize: 15),
                ),
                SizedBox(height: 60),
                // Display weather animation
                Container(
                  child: Stack(
                    children: <Widget>[
                        Lottie.asset(getWeatherAnimation(_weather?.mainCondition), height: 200),
                        Positioned(
                          bottom: 20, right: 5,
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: Icon(
                                Icons.volume_up,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                _playWeatherAudio();
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                // Display temperature
                Text(
                  '${_weather?.temperature.round()}°C',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                // Display main weather condition
                Text(
                  _weather?.mainCondition ?? "",
                  style: TextStyle(fontSize: 15)
                ),
                SizedBox(height: 20),
                // Display weather forecast
                _displayForecast(),
              ],
            ),
          ),
        ) : _loadWeatherUI(), // Show loading UI if weather data is not yet available
      ),
    );
  }

  // Widget to display a loading UI while fetching weather data
  Widget _loadWeatherUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          SizedBox(height: 20), // Space between the indicator and the text
          Text(
            'Fetching Weather Data...',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Widget to display the weather forecast
  Widget _displayForecast() {
    // Generate a list of Card widgets from the weather forecast data
    List<Widget> cards = _weatherForecast!.dailyForecast.map((Weather weather) {
      // Each card displays an animation, temperature, and date
      return Card(
        child: Column(
          children: [
            // Weather animation based on the forecast condition
            Lottie.asset(getWeatherAnimation(weather.mainCondition), width: 100, height: 100),
            // Display the forecasted temperature
            Text('${weather.temperature.round()}°C'),
            // Display the forecasted date
            Text(weather.shortFormattedDate),
          ],
        ),
      );
    }).toList();

    // Determine the screen size to adjust the layout
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // Conditional layout based on whether the view should be horizontal
    if (isHorizontalView) {
      // Width of each card in horizontal view
      double cardWidth = screenWidth / 5.0;
      // Display forecast cards in a horizontal scroll view
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: cards.map((card) => SizedBox(width: cardWidth, child: card)).toList(),
        ),
      );
    } else {
      // Height of each card in vertical view
      double cardHeight = screenHeight / 12.5;
      // Create cards for vertical layout
      List<Widget> verticalCards = _weatherForecast!.dailyForecast.map((Weather weather) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            height: cardHeight,
            child: Card(
              child: Row(
                children: [
                  // Weather animation
                  Expanded(
                    flex: 1,
                    child: Lottie.asset(getWeatherAnimation(weather.mainCondition), fit: BoxFit.contain),
                  ),
                  // Temperature and date
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
      // Return the forecast cards in a vertical layout
      return Column(children: verticalCards);
    }
  }

  @override
  void dispose() {
    // Clean up controllers and subscriptions when the widget is disposed
    super.dispose();
    // Cancel the barometer and battery level subscriptions
    _barometerSubscription?.cancel();  
    _batteryLevelSubscription?.cancel();
  }
}