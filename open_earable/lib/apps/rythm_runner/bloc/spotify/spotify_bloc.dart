import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';
import 'package:open_earable/apps/rythm_runner/bloc/simple_event_bus.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_app_settings_storage.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_settings.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_user_credentials_storage.dart';
import 'package:open_earable/apps/rythm_runner/bloc/tracker/tracker_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spotify/spotify.dart';
import 'package:app_links/app_links.dart';

part 'spotify_event.dart';
part 'spotify_state.dart';

/// This is the Bloc class handling the event
/// listeners (logic) for spotify related events
class SpotifyBloc extends Bloc<SpotifyEvent, SpotifyState> {
  // File storage for the Spotify App API settings
  SpotifyAppSettingsStorage _appSettingsStorage = SpotifyAppSettingsStorage();
  // File storage for the Spotify User Credentials
  SpotifyUserCredentialsStorage _userCredentialsStorage =
      SpotifyUserCredentialsStorage();

  // App links instance to listen for external links to open this app.
  // In this case, we use this to listen for the Spotify callback URL.
  AppLinks _appLinks = AppLinks();

  SpotifyBloc()
      // Initialize with empty settings
      : super(SpotifyDefault(SpotifySettingsData(
            spotifyClientId: "",
            spotifyClientSecret: "",
            selectedDeviceId: SpotifySettingsData.NO_DEVICE,
            devices: Iterable.empty(),
            idDeviceMap: Map()))) {
    // Listen for PlaySong, PausePlayback and UpdateDeviceList events on event bus
    SimpleEventBus().stream.listen((event) {
      if (!this.isClosed) {
        if (event is PlaySpotifySong ||
            event is PauseSpotifyPlayback ||
            event is UpdateDeviceList) {
          add(event);
        }
      }
    });

    // Load stored app settings and user credentials
    on<LoadStoredData>((event, emit) async {
      // Check if app settings exist
      if (await _appSettingsStorage.spotifyAppSettingsExist()) {
        // If they to, read the map from the storage and emit a new state
        // containining the clientId and clientSecret
        Map<String, dynamic>? appSettings =
            await _appSettingsStorage.readSpotifyAppSettings();
        if (appSettings != null &&
            appSettings.containsKey("clientId") &&
            appSettings.containsKey("clientSecret")) {
          emit(SpotifyDefault(await state.spotifySettings
              .copyWith(
                  spotifyClientId: appSettings["clientId"],
                  spotifyClientSecret: appSettings["clientSecret"])
              .setupSpotifyGrant()));
        }
      }
      // Check if clientId and clientSecret are present and there are saved user credentials
      if (state.spotifySettings.spotifyClientId != "" &&
          state.spotifySettings.spotifyClientSecret != "" &&
          await _userCredentialsStorage.userCredentialsExist()) {
        // Load user credentials and set up Spotify API instance
        SpotifyApiCredentials? credentials =
            await _userCredentialsStorage.readUserCredentials();
        if (credentials != null) {
          SpotifyApi spotifyApi = SpotifyApi(credentials);
          add(UpdateSpotifyApi(spotifyApi: spotifyApi));
        }
      }
      // Start listener for external links that lead to this app
      _appLinks.allStringLinkStream.listen((String? url) async {
        if (url == null) {
          return;
        }
        // Check if URL is relevant to this app
        if (url.startsWith(state.spotifySettings.redirectUrl)) {
          var readuri;
          if ((readuri = Uri.tryParse(url)) == null) {
            print("error parsing");
          } else {
            if (readuri.queryParameters == null) {
              return;
            }
            // Call event with recieved Uri, if it is valid and parsed correctly
            add(RecieveAuthLink(recievedUri: readuri));
          }
        }
      });
    });

    // React to an authentication link from Spotify
    on<RecieveAuthLink>((event, emit) async {
      // Ignore the link, if we already have a Spotify API Interface
      if (state.spotifySettings.spotifyInterface != null) {
        return;
      }
      try {
        if (state.spotifySettings.grant == null) {
          return;
        }
        // Handle the URI and retrieve the client from it
        var client = await state.spotifySettings.grant
            .handleAuthorizationResponse(event.recievedUri.queryParameters);
        // Create a new Spotify API Interface and save the new credentials
        var spotify = SpotifyApi.fromClient(client);
        SpotifyApiCredentials credentials = await spotify.getCredentials();
        if (!(await _userCredentialsStorage.userCredentialsExist())) {
          await _userCredentialsStorage.writeUserCredentials(credentials);
        }
        // Trigger the update event with the new Spotify API Interface
        add(UpdateSpotifyApi(spotifyApi: spotify));
      } on AuthorizationException catch (e) {
        print(
            "authorization exception. can most likely be ignored, related to api issue: $e");
      } on Error catch (e, st) {
        print("error: $e $st");
      }
    });

    // React to a new Spotify API Interface
    on<UpdateSpotifyApi>((event, emit) async {
      // Create a new settings object with the new API Interface
      SpotifySettingsData newSettings = state.spotifySettings;
      newSettings = newSettings.copyWith(spotifyInterface: event.spotifyApi);
      // Delete the current user credentials. By deleting these credentials
      // and refreshing them, we handle the fetching of a refresh token automatically.
      await _userCredentialsStorage.deleteUserCredentials();
      try {
        // Fetch the username from the new API Interface and save it to the settings.
        // Write the new user credentials from the API Interface to the storage file.
        User user = await event.spotifyApi.me.get();
        newSettings = newSettings.copyWith(spotifyName: user.displayName);
        await _userCredentialsStorage
            .writeUserCredentials(await event.spotifyApi.getCredentials());

        // Update the device list and emit the Default state with the new settings
        add(UpdateDeviceList());
        emit(SpotifyDefault(newSettings));
      } catch (ex, st) {
        // Remove the Spotify API Interface, delete stored
        // credentials and emit the error state.
        newSettings = newSettings.copyWithoutSpotifyApi();
        await _userCredentialsStorage.deleteUserCredentials();
        print("auth exception: $ex with stacktrace $st");
        emit(SpotifyError(newSettings,
            message:
                "An error occurred while authenticating with the Spotify API. Please re-connect your account: " + ex.toString()));
      }
    });

    // React to a change in the selected playback device
    on<UpdateSelectedDevice>((event, emit) {
      // Emit the current state with the new device id
      emit(state.copyWith(
          config: state.spotifySettings
              .copyWith(selectedDeviceId: event.newDeviceId)));
    });

    // React to new App API Settings (clientId and clientSecret) input
    on<UpdateSpotifyAppSettings>((event, emit) async {
      // Delete current data, then save new data
      await _userCredentialsStorage.deleteUserCredentials();
      await _appSettingsStorage.deleteSpotifyAppSettings();
      await _appSettingsStorage.saveSpotifyAppSettings(
          event.clientId, event.clientSecret);
      // Emit default state without the Spotify API Interface but with the new app settings
      emit(SpotifyDefault(state.spotifySettings
          .copyWithoutSpotifyApi()
          .copyWith(
              spotifyClientId: event.clientId,
              spotifyClientSecret: event.clientSecret)));
      // If the new settings are not null, we request authorization automatically
      // by calling the RequestSpotifyAuth event and opening the auth page in the browser
      if (event.clientId != "" && event.clientSecret != "") {
        add(RequestSpotifyAuth());
      }
    });

    // React to request to delete the saved user credentials
    on<DeleteSpotifyUserCredentials>((event, emit) async {
      // Delete credentials file and return state without Spotify API Interface
      await _userCredentialsStorage.deleteUserCredentials();
      emit(state.copyWith(
          config: state.spotifySettings.copyWithoutSpotifyApi().copyWith(
              spotifyName: null,
              selectedDeviceId: SpotifySettingsData.NO_DEVICE)));
    });

    // React to authentication request
    on<RequestSpotifyAuth>((event, emit) async {
      // Setup the grant and emit state with new settings
      SpotifySettingsData newSettings =
          await state.spotifySettings.setupSpotifyGrant();
      emit(SpotifyDefault(newSettings));
      // Open the auth url in the browser
      _openExternalUrl(newSettings.authUrl.toString());
    });

    // React to request to update the device list
    on<UpdateDeviceList>((event, emit) async {
      // Only update device list if there is a Spotify API Interface
      if (state.spotifySettings.spotifyInterface != null) {
        // Fetch currently available devices
        Iterable<Device> devices;
        try {
          devices =
              await state.spotifySettings.spotifyInterface!.player.devices();
        } catch (ex, st) {
          // Reset credentials on fail and enter Error state
          print("exception: $ex with stacktrace $st");
          add(DeleteSpotifyUserCredentials());
          emit(SpotifyError(state.spotifySettings,
              message:
                  "An error occurred while authenticating with the Spotify API. Please re-connect your account."));
          return;
        }
        // Cancel tracking if there are no devices available
        if (devices.length == 0) {
          SimpleEventBus().sendEvent(CancelTracking());
        }
        // Check if our currently selected device is still available.
        // If not, cancel tracking and update the selected device.
        String? newSelectedDevice = state.spotifySettings.selectedDeviceId;
        if (!devices
            .map((e) => e.id)
            .contains(state.spotifySettings.selectedDeviceId)) {
          SimpleEventBus().sendEvent(CancelTracking());
          newSelectedDevice = SpotifySettingsData.NO_DEVICE;
          add(UpdateSelectedDevice(newDeviceId: SpotifySettingsData.NO_DEVICE));
        }
        Map<String, Device> idDeviceMap = Map();
        // Register all available devices
        devices.forEach((element) {
          if (element.id == null) {
            return;
          }
          // Assign ids to new device map
          idDeviceMap[element.id!] = element;
          // Assign a new device, if there is currently none selected
          if (newSelectedDevice == SpotifySettingsData.NO_DEVICE) {
            newSelectedDevice = element.id;
            add(UpdateSelectedDevice(newDeviceId: newSelectedDevice));
            emit(SpotifyDefault(state.spotifySettings
                .copyWith(selectedDeviceId: newSelectedDevice)));
          }
        });
        // Emit a copy of the current state with the new settings,
        // including the selected device, device map and device list
        emit(state.copyWith(
            config: state.spotifySettings.copyWith(
          selectedDeviceId: newSelectedDevice,
          idDeviceMap: idDeviceMap,
          devices: devices,
        )));
        return;
      }
      emit(SpotifyDefault(state.spotifySettings.copyWith(
          selectedDeviceId: SpotifySettingsData.NO_DEVICE,
          devices: Iterable.empty(),
          idDeviceMap: Map())));
    });

    // React to request to play a song
    on<PlaySpotifySong>((event, emit) async {
      // Check if there is a Spotify API Interface and a selected device
      if (state.spotifySettings.spotifyInterface != null) {
        if (state.spotifySettings.selectedDeviceId ==
            SpotifySettingsData.NO_DEVICE) {
          return;
        }
        // If there is both, try to start or resume playback
        try {
          await state.spotifySettings.spotifyInterface!.player
              .startOrResume(
                  deviceId: state.spotifySettings.selectedDeviceId,
                  // Handle playing differently, depending on
                  // if we get passed a track or a playlist/album
                  options: event.mediaKey.contains(":track:")
                      ? StartOrResumeOptions(
                          positionMs: event.positionMs,
                          offset: PositionOffset(0),
                          uris: [event.mediaKey])
                      : StartOrResumeOptions(
                          positionMs: 0,
                          offset: PositionOffset(0),
                          contextUri: event.mediaKey))
              .then((value) {
            // If the request is successful, update the playingOnDeviceId parameter
            emit(SpotifyDefault(state.spotifySettings.copyWith(
                playingOnDeviceId: state.spotifySettings.selectedDeviceId)));
          });
        } on FormatException catch (ex) {
          // This error seems to happen because of the API. It does not seem
          // to cause any issues, which is why it is only logged here.
          print(
              "A FormatException related to the SpotifyAPI occurred. This can most likely be ignored: $ex");
        } catch (ex, st) {
          print("exception: $ex with stacktrace $st");
          // Trigger a Device List update, in most cases the target
          // device is no longer available
          add(UpdateDeviceList());
          if (ex is AuthorizationException) {
            // If there is an authorization exception we reset the user credentials
            // and enter the Spoify Error state.
            await _userCredentialsStorage.deleteUserCredentials();
            emit(SpotifyError(state.spotifySettings.copyWithoutSpotifyApi(),
                message:
                    "An error occurred while authenticating with the Spotify API. Please re-connect your account."));
          } else {
            // Enter Spotify Error state and encourage user to check devices.
            emit(SpotifyError(state.spotifySettings,
                message:
                    "Spotify-API rejected playback on selected device. Please make sure the device you selected is online. The player for mobile devices in particular gets disabled very quickly, in which case you need to open the Spotify app to reactivate it."));
          }
          return;
        }
      }
    });

    // React to request to pause playback
    on<PauseSpotifyPlayback>((event, emit) async {
      // Return if there is no known playback
      if (state.spotifySettings.playingOnDeviceId == null ||
          state.spotifySettings.playingOnDeviceId ==
              SpotifySettingsData.NO_DEVICE) {
        return;
      }
      // If there is a device, try to pause playback
      try {
        await state.spotifySettings.spotifyInterface!.player
            .pause(deviceId: state.spotifySettings.playingOnDeviceId);
        emit(SpotifyDefault(state.spotifySettings
            .copyWith(playingOnDeviceId: SpotifySettingsData.NO_DEVICE)));
      } on FormatException catch (ex) {
        // This error seems to happen because of the API. It does not seem
        // to cause any issues, which is why it is only logged here.
        print(
            "A FormatException related to the SpotifyAPI occurred. This can most likely be ignored: $ex");
      } catch (ex, st) {
        print("exception: $ex with stacktrace $st");
        // Trigger a Device List update, in most cases the target
        // device is no longer available
        add(UpdateDeviceList());
        if (ex is AuthorizationException) {
          // If there is an authorization exception we reset the user credentials
          // and enter the Spoify Error state.
          await _userCredentialsStorage.deleteUserCredentials();
          emit(SpotifyError(state.spotifySettings.copyWithoutSpotifyApi(),
              message:
                  "An error occurred while authenticating with the Spotify API. Please re-connect your account."));
          return;
        } else {
          // Enter Spotify Error state and encourage user to check devices.
          emit(SpotifyError(
              state.spotifySettings
                  .copyWith(playingOnDeviceId: SpotifySettingsData.NO_DEVICE),
              message:
                  "Spotify-API rejected pausing playback on selected device. Please make sure the device you selected is online."));
          return;
        }
      }
    });
  }

  /// This function opens the given URL in an external browser if possible.
  ///
  /// Args:
  ///   url (String): The url that is supposed to be opened.
  Future<void> _openExternalUrl(String url) async {
    // Parse and check if it is a valid uri
    Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      throw "Invalid uri $url";
    }
    // Check if the Url can be launched. If so, do so in external App, otherwise throw error
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw "Could not launch $url";
    }
  }
}
