import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// This class is used to store the Spotify App API Settings in a
/// JSON file, so it can be loaded automatically when the app starts.
class SpotifyAppSettingsStorage {
  // Get the directory where we save our files
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Get the path to our storage file
  Future<File> get _localSpotifyAppFile async {
    final path = await _localPath;
    return File("$path/spotify_app_settings.json");
  }

  /// This function saves the given App Settings to the file.
  /// 
  /// Args:
  ///   clientId (String): Spotify clientId parameter
  ///   clientSecret (String): Spotify clientSecret paramater
  Future<void> saveSpotifyAppSettings(
      String clientId, String clientSecret) async {
    final file = await _localSpotifyAppFile;
    final data = {
      "clientId": clientId,
      "clientSecret": clientSecret,
    };
    await file.writeAsString(json.encode(data));
  }


  /// This function returns a Map containing the stored clientID and clientSecret
  /// 
  /// Returns:
  ///   a Map containing the stored clientID and clientSecret, or null if it doesn't exist
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

  /// This function deletes the stored App Settings.
  /// 
  /// Returns:
  ///   True, if deletion is successful.
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
  
  /// This function checks if a file containing the App settings exists
  /// 
  /// Returns:
  ///   true, if such a file exists
  Future<bool> spotifyAppSettingsExist() async {
    try {
      final file = await _localSpotifyAppFile;
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}