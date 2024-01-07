part of 'spotify_bloc.dart';

@immutable
sealed class SpotifyEvent {}

class LoadStoredData extends SpotifyEvent {}

class RecieveAuthLink extends SpotifyEvent {
  final Uri recievedUri;

  RecieveAuthLink({required this.recievedUri});
}

class UpdateSelectedDevice extends SpotifyEvent {
  final String? newDeviceId;

  UpdateSelectedDevice({this.newDeviceId});
}

class UpdateSpotifyApi extends SpotifyEvent {
  final SpotifyApi spotifyApi;

  UpdateSpotifyApi({required this.spotifyApi});
}

class UpdateDeviceList extends SpotifyEvent {}

class UpdateSpotifyAppSettings extends SpotifyEvent {
  final String clientId;
  final String clientSecret;

  UpdateSpotifyAppSettings(
      {required this.clientId, required this.clientSecret});
}

class DeleteSpotifyUserCredentials extends SpotifyEvent {}

class RequestSpotifyAuth extends SpotifyEvent {}

class PlaySpotifySong extends SpotifyEvent {
  final String mediaKey;

  PlaySpotifySong({required this.mediaKey});
}

class PauseSpotifyPlayback extends SpotifyEvent {}
