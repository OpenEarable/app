import 'package:open_earable/apps/earable_weather/models/weather-model.dart';

class WeatherForecast {
  final List<Weather> dailyForecast;

  WeatherForecast({required this.dailyForecast});

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    var list = json['list'] as List;
    List<Weather> forecastList = [];

    // Process the list to create a daily forecast
    for (int i = 0; i < list.length; i+=8) { // Assumes 8 entries per day
      var weatherJson = list[i];
      forecastList.add(Weather.fromJson(weatherJson));
    }

    return WeatherForecast(dailyForecast: forecastList);
  }
}
