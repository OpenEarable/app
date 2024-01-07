part of 'spotify_bloc.dart';

@immutable
sealed class SpotifyEvent {}

// Event to load stored app and user auth data
class LoadStoredData extends SpotifyEvent {}

// Event to handle a recieved authorization callback
class RecieveAuthLink extends SpotifyEvent {
  // The callback link containing the access-token etc
  final Uri recievedUri;

  RecieveAuthLink({required this.recievedUri});
}

// Event to update the selected playback device
class UpdateSelectedDevice extends SpotifyEvent {
  final String? newDeviceId;

  UpdateSelectedDevice({this.newDeviceId});
}

// Event to update the SpotifyAPI interface (new credentials, outdated token, ...)
class UpdateSpotifyApi extends SpotifyEvent {
  final SpotifyApi spotifyApi;

  UpdateSpotifyApi({required this.spotifyApi});
}

// Event to update the list of available playback devices
class UpdateDeviceList extends SpotifyEvent {}

// Event to update the Spotify app API settings
class UpdateSpotifyAppSettings extends SpotifyEvent {
  final String clientId;
  final String clientSecret;

  UpdateSpotifyAppSettings(
      {required this.clientId, required this.clientSecret});
}

// Event to delete the stored user credentials
class DeleteSpotifyUserCredentials extends SpotifyEvent {}

// Event to request authorization with Spotify
class RequestSpotifyAuth extends SpotifyEvent {}

// Event to play the song provided in the mediaKey
class PlaySpotifySong extends SpotifyEvent {
  final String mediaKey;

  PlaySpotifySong({required this.mediaKey});
}

// Event to pause playback on the currently selected device
class PauseSpotifyPlayback extends SpotifyEvent {}
