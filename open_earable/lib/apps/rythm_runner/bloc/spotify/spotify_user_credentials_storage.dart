import 'dart:async';
import 'package:spotify/spotify.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// This class is used to store the Spotify User Credentials in a
/// JSON file, so it can be loaded automatically when the app starts.
class SpotifyUserCredentialsStorage {
  // Get the directory where we save our files
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Get the path to our storage file
  Future<File> get _localUserCredentialsFile async {
    final path = await _localPath;
    return File("$path/spotify_credentials.json");
  }


  /// This function builds and returns a map based on the SpotifyAPICredentials object it is passed
  /// 
  /// Args:
  ///   credentials (SpotifyApiCredentials): object containing all relevant API credentials
  /// 
  /// Returns:
  ///   a Map<String, dynamic> containing all relevant information from the credentials.
  Map<String, dynamic> _userCredentialsToMap(
      SpotifyApiCredentials credentials) {
    return {
      "clientId": credentials.clientId,
      "clientSecret": credentials.clientSecret,
      "accessToken": credentials.accessToken,
      "refreshToken": credentials.refreshToken,
      "scopes": jsonEncode(credentials.scopes),
      "expiration": credentials.expiration?.toIso8601String(),
    };
  }

  /// This function builds and returns a SpotifyApiCredentials object from
  /// the values provided in the map.
  /// 
  /// Args:
  ///   map (Map<String, dynamic>): A map containing all relevant Spotify Credentials info
  /// 
  /// Returns:
  ///   a new SpotifyApiCredentials instance generated from the map
  SpotifyApiCredentials _mapToUserCredentials(Map<String, dynamic> map) {
    return SpotifyApiCredentials(
      map["clientId"],
      map["clientSecret"],
      accessToken: map["accessToken"],
      refreshToken: map["refreshToken"],
      scopes: map["scopes"] != null
          ? List<String>.from(jsonDecode(map["scopes"]))
          : null,
      expiration:
          map["expiration"] != null ? DateTime.parse(map["expiration"]) : null,
    );
  }

  /// This function saves the given Spotify Credentials to the file.
  /// 
  /// Args:
  ///   credentials (SpotifyApiCredentials): User Credentials containing info such as the access-token
  /// 
  /// Returns:
  ///   The method is returning a `Future<File>`.
  Future<void> writeUserCredentials(SpotifyApiCredentials credentials) async {
    final file = await _localUserCredentialsFile;
    String json = jsonEncode(_userCredentialsToMap(credentials));
    await file.writeAsString(json);
  }

  /// This function returns a SpotifyCredentials object, containing the users credentials to access the API
  /// 
  /// Returns:
  ///   a SpotifyCredentials object, or null if it doesn't exist
  Future<SpotifyApiCredentials?> readUserCredentials() async {
    try {
      final file = await _localUserCredentialsFile;
      String json = await file.readAsString();
      Map<String, dynamic> jsonMap = jsonDecode(json);
      return _mapToUserCredentials(jsonMap);
    } catch (e) {
      return null;
    }
  }

  /// This function deletes the stored Spotify Credentials.
  /// 
  /// Returns:
  ///   True, if deletion is successful.
  Future<bool> deleteUserCredentials() async {
    try {
      final file = await _localUserCredentialsFile;
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// This function checks if a file containing the SpotifyCredentials exists
  /// 
  /// Returns:
  ///   true, if such a file exists
  Future<bool> userCredentialsExist() async {
    try {
      final file = await _localUserCredentialsFile;
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
