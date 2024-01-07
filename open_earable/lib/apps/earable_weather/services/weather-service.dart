import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:open_earable/apps/earable_weather/models/weather-forecast-model.dart';
import 'package:open_earable/apps/earable_weather/models/weather-model.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static const BASE_URL = 'https://api.openweathermap.org/data/2.5/';
  final String apiKey;  

  late bool serviceEnabled;
  late LocationPermission permission;

  WeatherService(this.apiKey);

  Future<Weather> getWeather(String cityName) async {
    final response = await http.get(Uri.parse('${BASE_URL}weather?q=${cityName}&appid=${apiKey}&units=metric'));

    if(response.statusCode == 200) {
      return Weather.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load weather');
    }
  }

  Future<WeatherForecast> getForecast(String cityName) async {
    final response = await http.get(Uri.parse('${BASE_URL}forecast?q=${cityName}&appid=${apiKey}&units=metric'));

    if(response.statusCode == 200) {
      return WeatherForecast.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load forecast');
    }
  }

  Future<Position> _getCurrentPosition() async {
    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
            Get.snackbar('', 'Location Permission Denied');
            // Permissions are denied, next time you could try
            // requesting permissions again (this is also where
            // Android's shouldShowRequestPermissionRationale
            // returned true. According to Android guidelines
            // your App should show an explanatory UI now.
            return Future.error('Location permissions are denied');
          }
        }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<String> getCurrentCity() async {
    // Fetch the current location
    Position position = await _getCurrentPosition();
    // Convert the location into a list of placemark object
    List<Placemark> placemarks = 
      await placemarkFromCoordinates(position.latitude, position.longitude);
    // Extract the city name from the first placemark
    String? city = placemarks[0].locality;

    return city ?? "";
  }
}