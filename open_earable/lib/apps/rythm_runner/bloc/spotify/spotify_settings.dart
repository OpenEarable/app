import 'package:spotify/spotify.dart';

/// This is a data class used to store all relevant information
/// for the interaction with the Spotify API.
class SpotifySettingsData {
  // String used to represent no device being selected
  static final String NO_DEVICE = "no_device";
  // Map from BPM-Count to Playlist-ID used to play fitting music
  static final Map<int, String> BPM_PLAYLIST_MAP = {
    100: "5JpANhLlGcgZcLFcrNhL7j",
    105: "56cgN0YoqzPjmNBBuiVo6b",
    110: "2pX7htNxQUGZSObonznRyn",
    115: "78qmqXAefQPCbQ5JqfwWgz",
    120: "2rzL3ZFSz87245ljAic93z",
    125: "0NWDFIKxo5SWD6DcKtVki8",
    130: "1oaud9SKxuZqSrUExlJcqH",
    135: "1Nn50h5LJjrvwPaGmKdIdq",
    140: "37i9dQZF1EIgOKtiospcqN",
    145: "37i9dQZF1EIcB36Vij2P5d",
    150: "37i9dQZF1EIhmFUhSnzn5T",
    155: "37i9dQZF1EIeGfmJObJDc0",
    160: "37i9dQZF1EIdYV92VKrjuC",
    165: "37i9dQZF1EIcNylL4dr08W",
    170: "37i9dQZF1EIgfIackHptHl",
  };
  // A playlist containing ambient sounds to make sure playback is running
  static final String TICKING_PLAYLIST = "spotify:track:2F9xBxKbx2M0pbgtSu8fLf";

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
