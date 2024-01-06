import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:open_earable/apps/earable_weather/models/weather-model.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static const BASE_URL = 'ttps://api.openweathermap.org/data/2.5/weather';
  final String apiKey;  

  late bool serviceEnabled;
  late LocationPermission permission;

  WeatherService(this.apiKey);


}