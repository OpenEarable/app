import 'dart:async';
import 'package:spotify/spotify.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SpotifyUserCredentialsStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localUserCredentialsFile async {
    final path = await _localPath;
    return File("$path/spotify_credentials.json");
  }

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

  Future<File> writeUserCredentials(SpotifyApiCredentials credentials) async {
    final file = await _localUserCredentialsFile;
    String json = jsonEncode(_userCredentialsToMap(credentials));
    return file.writeAsString(json);
  }

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

  Future<bool> userCredentialsExist() async {
    try {
      final file = await _localUserCredentialsFile;
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
