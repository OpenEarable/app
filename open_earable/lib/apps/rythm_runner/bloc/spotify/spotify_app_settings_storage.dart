import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SpotifyAppSettingsStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localSpotifyAppFile async {
    final path = await _localPath;
    return File("$path/spotify_app_settings.json");
  }

  Future<void> saveSpotifyAppSettings(
      String clientId, String clientSecret) async {
    final file = await _localSpotifyAppFile;
    final data = {
      "clientId": clientId,
      "clientSecret": clientSecret,
    };
    await file.writeAsString(json.encode(data));
  }

  Future<Map<String, dynamic>?> readSpotifyAppSettings() async {
    try {
      final file = await _localSpotifyAppFile;
      if (await file.exists()) {
        String json = await file.readAsString();
        return jsonDecode(json);
      }
    } catch (e) {
    }
    return null;
  }

  Future<bool> deleteSpotifyAppSettings() async {
    try {
      final file = await _localSpotifyAppFile;
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> spotifyAppSettingsExist() async {
    try {
      final file = await _localSpotifyAppFile;
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}