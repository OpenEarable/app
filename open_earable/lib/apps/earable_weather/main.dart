import 'package:flutter/material.dart';
import 'package:open_earable/apps/earable_weather/pages/weather-page.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class EarableWeather extends StatelessWidget {
  final OpenEarable openEarable;

  EarableWeather({Key? key, required this.openEarable}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WeatherPage(openEarable),
    );
  }
}
