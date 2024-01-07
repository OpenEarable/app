part of 'spotify_bloc.dart';

@immutable
sealed class SpotifyState {
  final SpotifySettingsData spotifySettings;

  SpotifyState(this.spotifySettings);

  SpotifyState copyWith({SpotifySettingsData? config});
}

final class SpotifyDefault extends SpotifyState {
  SpotifyDefault(super.spotifySettings);
  
  @override
  SpotifyState copyWith({SpotifySettingsData? config}) {
    return SpotifyDefault(config ?? this.spotifySettings);
  }
}

final class SpotifyError extends SpotifyDefault {
  final String message;

  SpotifyError(super.spotifySettings, {required this.message});

  @override
  SpotifyError copyWith({SpotifySettingsData? config}) {
    return SpotifyError(config ?? this.spotifySettings, message: this.message);
  }
}