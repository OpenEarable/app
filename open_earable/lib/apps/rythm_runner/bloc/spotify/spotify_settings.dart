import 'package:spotify/spotify.dart';

/// This is a data class used to store all relevant information
/// for the interaction with the Spotify API.
class SpotifySettingsData {
  // String used to represent no device being selected
  static final String NO_DEVICE = "no_device";
  // Map from BPM-Count to Playlist-ID used to play fitting music
  static final Map<int, String> BPM_PLAYLIST_MAP = {
    // lower than this is unreasonable for "jogging"
    75: "65ZJ2rTPh7IvbR7GCBzVfA",
    80: "4zF5SxUc41DzhobxPBAIXI",
    85: "1Ta2ZS5RrpVbGfsLqOWjqZ",
    90: "1bS8K4F9XwIdYaaTM9Ljk6",
    95: "24TKSw6Q5nHiklACHSp8K3",
    100: "5JpANhLlGcgZcLFcrNhL7j",
    105: "56cgN0YoqzPjmNBBuiVo6b",
    110: "2pX7htNxQUGZSObonznRyn",
    115: "1cycBpBUiwGdibZAgbjFCI",
    120: "1vdkPd9esYFohPkUxcrUDa",
    125: "0NWDFIKxo5SWD6DcKtVki8",
    130: "1oaud9SKxuZqSrUExlJcqH",
    135: "1Nn50h5LJjrvwPaGmKdIdq",
    140: "6kxkTgQ7t8PeLjxuZ4paQU",
    145: "37i9dQZF1EIcB36Vij2P5d",
    150: "4Nh8LIfndaHVsRmHVDkx4t",
    155: "6HinIWAymRvmShRIPnUAuc",
    160: "7fdDgjOHEcwYgTQDP5OAnP",
    165: "633seQzRvT2wN6RdpmF6iy",
    170: "35PrVh06kXtf5RjxeScVQC",
    175: "1NlLHkjxFRndC2EIZjo7Hq",
    180: "6ANLVBNaJwjUdO6FxaHtAW",
    185: "1p2qEjroGbWabSosswTJAb",
    190: "37i9dQZF1EIcID9rq1OAoH",
    // above this is unreasonable for "jogging"
  };
  // A playlist containing ambient sounds to make sure playback is running
  static final String TICKING_TRACK = "spotify:track:2F9xBxKbx2M0pbgtSu8fLf";

  // App Settings for the App that controls the playback
  final String spotifyClientId;
  final String spotifyClientSecret;
  final String redirectUrl =
      "ekulos-edu-kit-teco-openearable-rythmrunner://callback/";

  // Spotify Interface, which we use to interact with the API 
  final SpotifyApi? spotifyInterface;

  // Data related to authentication with the API
  final SpotifyApiCredentials? credentials;
  final dynamic grant;
  final Uri? authUrl;

  // The connected users Spotify displayname
  final String? spotifyName;

  // A list of all available devices
  final Iterable<Device> devices;
  // The currently selected device
  final String selectedDeviceId;
  // The device we started playing on using the API
  final String? playingOnDeviceId;
  // A Map to identify a device and its information by its ID
  final Map<String, Device> idDeviceMap;

  SpotifySettingsData(
      {required this.spotifyClientId,
      required this.spotifyClientSecret,
      this.spotifyInterface,
      this.credentials,
      this.grant,
      this.spotifyName,
      required this.devices,
      this.authUrl,
      required this.selectedDeviceId,
      this.playingOnDeviceId,
      required this.idDeviceMap});

  SpotifySettingsData copyWith({
    String? spotifyClientId,
    String? spotifyClientSecret,
    SpotifyApi? spotifyInterface,
    SpotifyApiCredentials? credentials,
    dynamic grant,
    Uri? authUrl,
    String? spotifyName,
    Iterable<Device>? devices,
    String? selectedDeviceId,
    String? playingOnDeviceId,
    Map<String, Device>? idDeviceMap,
  }) {
    return SpotifySettingsData(
      spotifyClientId: spotifyClientId ?? this.spotifyClientId,
      spotifyClientSecret: spotifyClientSecret ?? this.spotifyClientSecret,
      spotifyInterface: spotifyInterface ?? this.spotifyInterface,
      credentials: credentials ?? this.credentials,
      grant: grant ?? this.grant,
      authUrl: authUrl ?? this.authUrl,
      spotifyName: spotifyName ?? this.spotifyName,
      devices: devices ?? this.devices,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      playingOnDeviceId: playingOnDeviceId ?? this.playingOnDeviceId,
      idDeviceMap: idDeviceMap ?? this.idDeviceMap,
    );
  }

  /// This function returns the current SpotifySettingsData with
  /// the exception of the spotifyInterface, devices, selectedDeviceId 
  /// and playingOnDeviceId. Those are all reset or set to null.
  SpotifySettingsData copyWithoutSpotifyApi() {
    return SpotifySettingsData(
      spotifyClientId: this.spotifyClientId,
      spotifyClientSecret: this.spotifyClientSecret,
      spotifyInterface: null,
      credentials: this.credentials,
      grant: this.grant,
      authUrl: this.authUrl,
      spotifyName: this.spotifyName,
      devices: Iterable.empty(),
      selectedDeviceId: NO_DEVICE,
      playingOnDeviceId: NO_DEVICE,
      idDeviceMap: this.idDeviceMap,
    );
  }

  /// This function sets up the spotify grant by passing the app credentials
  Future<SpotifySettingsData> setupSpotifyGrant() async {
    SpotifyApiCredentials newCredentials =
        SpotifyApiCredentials(spotifyClientId, spotifyClientSecret);
    dynamic newGrant = SpotifyApi.authorizationCodeGrant(newCredentials);
    // Permission scopes, that will be requested from the user
    final scopes = [
      "user-read-playback-state",
      "user-modify-playback-state",
      "user-read-currently-playing",
    ];

    return this.copyWith(
        credentials: newCredentials,
        grant: newGrant,
        // Setup the Autorization URL using the redirectUrl and the scopes
        authUrl: newGrant.getAuthorizationUrl(Uri.parse(redirectUrl),
            scopes: scopes));
  }

  @override
  String toString() {
    return 'SpotifySettingsData(spotifyClientId: $spotifyClientId, spotifyClientSecret: $spotifyClientSecret, spotifyInterface: $spotifyInterface, credentials: $credentials, grant: $grant, spotifyName: $spotifyName, selectedDeviceId: $selectedDeviceId, playingOnDeviceId: $playingOnDeviceId)';
  }

  @override
  bool operator ==(covariant SpotifySettingsData other) {
    if (identical(this, other)) return true;

    return other.spotifyClientId == spotifyClientId &&
        other.spotifyClientSecret == spotifyClientSecret &&
        other.spotifyInterface == spotifyInterface &&
        other.credentials == credentials &&
        other.grant == grant &&
        other.authUrl == authUrl &&
        other.spotifyName == spotifyName &&
        other.selectedDeviceId == selectedDeviceId &&
        other.playingOnDeviceId == playingOnDeviceId;
  }

  @override
  int get hashCode {
    return spotifyClientId.hashCode ^
        spotifyClientSecret.hashCode ^
        spotifyInterface.hashCode ^
        credentials.hashCode ^
        grant.hashCode ^
        authUrl.hashCode ^
        spotifyName.hashCode ^
        selectedDeviceId.hashCode ^
        playingOnDeviceId.hashCode;
  }
}
