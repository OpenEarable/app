import 'package:open_earable/apps/earable_weather/utils/date-converter.dart';

class Weather {
  final String cityName;
  final double temperature;
  final String mainCondition;
  final DateTime date; // Added date field

  Weather({
    required this.cityName,
    required this.temperature,
    required this.mainCondition,
    required this.date, // Add date to constructor
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    String cityName = json['name'] as String? ?? 'Unknown';
    double temperature = (json['main']['temp'] as num?)?.toDouble() ?? 0.0;
    String mainCondition = (json['weather'][0]['main'] as String?) ?? 'Unknown';
    int timestamp = json['dt'] as int? ?? 0;
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

    return Weather(
      cityName: cityName, 
      temperature: temperature, 
      mainCondition: mainCondition,
      date: date,
    );
  }

  // Convenience getters for formatted dates
  String get longFormattedDate => createDate(date.millisecondsSinceEpoch, "long");
  String get shortFormattedDate => createDate(date.millisecondsSinceEpoch, "short");
}
