import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

class WeatherUtils {
  static Future<String> convertWeatherToSpeech(String weatherData) async {
    FlutterTts flutterTts = FlutterTts();

    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(1.0);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    Directory tempDir = await getTemporaryDirectory();
    String tempFilePath = '${tempDir.path}/weather_info_temp.wav';
    await flutterTts.synthesizeToFile(weatherData, tempFilePath);

     // Convert the file format
    String outputFilePath = '${tempDir.path}/weather_info.wav';
    await convertAudioFile(tempFilePath, outputFilePath);

    await flutterTts.synthesizeToFile(weatherData, outputFilePath);

    // Return the file path for further use
    return outputFilePath;
  }

  static Future<void> convertAudioFile(String inputFilePath, String outputFilePath) async {
    FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

    // Check if the output file already exists
    if (await fileExists(outputFilePath)) {
      // Delete the existing file
      await deleteFile(outputFilePath);
    }
    
    String command = "-i $inputFilePath -acodec pcm_s16le -ac 1 -ar 44100 $outputFilePath";
    await _flutterFFmpeg.execute(command).then((returnCode) {
      if (returnCode == 0) {
        print("Conversion successful");
      } else {
        print("Conversion failed with returnCode: $returnCode");
      }
    });
  }

  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return file.exists();
  }

  static Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
