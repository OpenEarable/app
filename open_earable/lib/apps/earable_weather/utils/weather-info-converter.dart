import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

class WeatherUtils {
  static Future<String> convertWeatherToSpeech(String weatherData) async {
    FlutterTts flutterTts = FlutterTts();

    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(1.0);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    Directory tempDir = await getTemporaryDirectory();
    String filePath = '${tempDir.path}/weather_info.wav';

    await flutterTts.synthesizeToFile(weatherData, filePath);

    // Return the file path for further use
    return filePath;
  }
}
