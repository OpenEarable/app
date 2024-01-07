part of 'spotify_bloc.dart';

@immutable
sealed class SpotifyState {
  final SpotifySettingsData spotifySettings;

  SpotifyState(this.spotifySettings);

  SpotifyState copyWith({SpotifySettingsData? config});
}

/// This is the default Spotify state, handling all normal API interaction
final class SpotifyDefault extends SpotifyState {
  SpotifyDefault(super.spotifySettings);
  
  @override
  SpotifyState copyWith({SpotifySettingsData? config}) {
    return SpotifyDefault(config ?? this.spotifySettings);
  }
}

/// This is an error state, which is entered, when an API call causes an issue
final class SpotifyError extends SpotifyDefault {
  // The error message, which is displayed in an error banner
  final String message;

  SpotifyError(super.spotifySettings, {required this.message});

  @override
  SpotifyError copyWith({SpotifySettingsData? config}) {
    return SpotifyError(config ?? this.spotifySettings, message: this.message);
  }
}