class Weather {
  final String cityName;
  final double temperature;
  final String mainCondition;

  Weather({
    required this.cityName,
    required this.temperature,
    required this.mainCondition,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    String cityName = json['name'] as String? ?? 'Unknown';
    double temperature = (json['main']['temp'] as num?)?.toDouble() ?? 0.0;
    String mainCondition = (json['weather'][0]['main'] as String?) ?? 'Unknown';

    return Weather(
      cityName: cityName, 
      temperature: temperature, 
      mainCondition: mainCondition,
    );
  }
}