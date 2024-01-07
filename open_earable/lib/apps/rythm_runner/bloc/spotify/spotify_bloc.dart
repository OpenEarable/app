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

class SpotifyBloc extends Bloc<SpotifyEvent, SpotifyState> {
  SpotifyAppSettingsStorage appSettingsStorage = SpotifyAppSettingsStorage();
  SpotifyUserCredentialsStorage userCredentialsStorage =
      SpotifyUserCredentialsStorage();
  AppLinks _appLinks = AppLinks();

  SpotifyBloc()
      : super(SpotifyDefault(SpotifySettingsData(
            spotifyClientId: "",
            spotifyClientSecret: "",
            selectedDeviceId: SpotifySettingsData.NO_DEVICE,
            devices: Iterable.empty(),
            idDeviceMap: Map()))) {
    SimpleEventBus().stream.listen((event) {
      if (event is PlaySpotifySong ||
          event is PauseSpotifyPlayback ||
          event is UpdateDeviceList) {
        if (!this.isClosed) {
          add(event);
        }
      }
    });

    on<LoadStoredData>((event, emit) async {
      if (await appSettingsStorage.spotifyAppSettingsExist()) {
        Map<String, dynamic>? appSettings =
            await appSettingsStorage.readSpotifyAppSettings();
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
      if (state.spotifySettings.spotifyClientId != "" &&
          state.spotifySettings.spotifyClientSecret != "" &&
          await userCredentialsStorage.userCredentialsExist()) {
        SpotifyApiCredentials? credentials =
            await userCredentialsStorage.readUserCredentials();
        if (credentials != null) {
          SpotifyApi spotifyApi = SpotifyApi(credentials);
          add(UpdateSpotifyApi(spotifyApi: spotifyApi));
        }
      }
      _appLinks.allStringLinkStream.listen((String? url) async {
        if (url == null) {
          return;
        }
        if (url.startsWith(state.spotifySettings.redirectUrl)) {
          var readuri;
          if ((readuri = Uri.tryParse(url)) == null) {
            print("error parsing");
          } else {
            if (readuri.queryParameters == null) {
              return;
            }
            add(RecieveAuthLink(recievedUri: readuri));
          }
        }
      });
    });
    on<RecieveAuthLink>((event, emit) async {
      if (state.spotifySettings.spotifyInterface != null) {
        return;
      }
      try {
        if (state.spotifySettings.grant == null) {
          return;
        }
        var client = await state.spotifySettings.grant
            .handleAuthorizationResponse(event.recievedUri.queryParameters);
        var spotify = SpotifyApi.fromClient(client);
        SpotifyApiCredentials credentials = await spotify.getCredentials();
        if (!(await userCredentialsStorage.userCredentialsExist())) {
          await userCredentialsStorage.writeUserCredentials(credentials);
        }
        add(UpdateSpotifyApi(spotifyApi: spotify));
      } on AuthorizationException catch (e) {
        print("authorization exception. can most likely be ignored, related to api issue: $e");
      } on Error catch (e, st) {
        print("error: $e $st");
      }
    });
    on<UpdateSpotifyApi>((event, emit) async {
      SpotifySettingsData newSettings = state.spotifySettings;
      newSettings = newSettings.copyWith(spotifyInterface: event.spotifyApi);
      await userCredentialsStorage.deleteUserCredentials();
      try {
        User user = await event.spotifyApi.me.get();
        newSettings = newSettings.copyWith(spotifyName: user.displayName);
        await userCredentialsStorage
            .writeUserCredentials(await event.spotifyApi.getCredentials());
        /*_showSnackBarText(
          context, "Successfully connected to Spotify account: $_spotifyName");*/
        add(UpdateDeviceList());
        emit(SpotifyDefault(newSettings));
      } on AuthorizationException catch (ex, st) {
        newSettings = newSettings.copyWithoutSpotifyApi();
        await userCredentialsStorage.deleteUserCredentials();
        print("auth exception: $ex with stacktrace $st");
        emit(SpotifyError(newSettings,
            message:
                "An error occurred while authenticating with the Spotify API. Please re-connect your account."));
      }
    });
    on<UpdateSelectedDevice>((event, emit) {
      emit(state.copyWith(
          config: state.spotifySettings
              .copyWith(selectedDeviceId: event.newDeviceId)));
    });
    on<UpdateSpotifyAppSettings>((event, emit) async {
      await userCredentialsStorage.deleteUserCredentials();
      await appSettingsStorage.deleteSpotifyAppSettings();
      await appSettingsStorage.saveSpotifyAppSettings(
          event.clientId, event.clientSecret);
      emit(SpotifyDefault(state.spotifySettings
          .copyWithoutSpotifyApi()
          .copyWith(
              spotifyClientId: event.clientId,
              spotifyClientSecret: event.clientSecret)));
      if (event.clientId != "" && event.clientSecret != "") {
        add(RequestSpotifyAuth());
      }
    });
    on<DeleteSpotifyUserCredentials>((event, emit) async {
      await userCredentialsStorage.deleteUserCredentials();
      emit(state.copyWith(
          config: state.spotifySettings.copyWithoutSpotifyApi().copyWith(
              spotifyName: null,
              selectedDeviceId: SpotifySettingsData.NO_DEVICE)));
      /*_showSnackBarText(
          context, "Your account was unlinked successfully.");*/
    });
    on<RequestSpotifyAuth>((event, emit) async {
      SpotifySettingsData newSettings =
          await state.spotifySettings.setupSpotifyGrant();
      emit(SpotifyDefault(newSettings));
      _openExternalUrl(newSettings.authUrl.toString());
    });
    on<UpdateDeviceList>((event, emit) async {
      if (state.spotifySettings.spotifyInterface != null) {
        Iterable<Device> devices;
        try {
          devices =
              await state.spotifySettings.spotifyInterface!.player.devices();
        } catch (ex, st) {
          print("auth exception: $ex with stacktrace $st");
          add(DeleteSpotifyUserCredentials());
          emit(SpotifyError(state.spotifySettings,
              message:
                  "An error occurred while authenticating with the Spotify API. Please re-connect your account."));
          return;
        }
        if (devices.length == 0) {
          SimpleEventBus().sendEvent(CancelTracking());
        }
        if (!devices
            .map((e) => e.id)
            .contains(state.spotifySettings.selectedDeviceId)) {
          SimpleEventBus().sendEvent(CancelTracking());
          add(UpdateSelectedDevice(newDeviceId: SpotifySettingsData.NO_DEVICE));
        }
        Map<String, Device> idDeviceMap = Map();
        String? newSelectedDevice = state.spotifySettings.selectedDeviceId;
        devices.forEach((element) {
          if (element.id == null) {
            return;
          }
          if (element.isActive != null && !element.isActive!) {
            return;
          }
          idDeviceMap[element.id!] = element;
          if (state.spotifySettings.selectedDeviceId ==
              SpotifySettingsData.NO_DEVICE) {
            newSelectedDevice = element.id;
            add(UpdateSelectedDevice(newDeviceId: newSelectedDevice));
            emit(SpotifyDefault(state.spotifySettings
                .copyWith(selectedDeviceId: newSelectedDevice)));
          }
        });
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
    on<PlaySpotifySong>((event, emit) async {
      if (state.spotifySettings.spotifyInterface != null) {
        if (state.spotifySettings.selectedDeviceId ==
            SpotifySettingsData.NO_DEVICE) {
          return;
        }
        try {
          await state.spotifySettings.spotifyInterface!.player
              .startOrResume(
                  deviceId: state.spotifySettings.selectedDeviceId,
                  options: StartOrResumeOptions(
                      positionMs: 0,
                      offset: PositionOffset(0),
                      contextUri: event.mediaKey))
              .then((value) {
            //_showSnackBarText(context, "Started playlist at $bpmInFives BPM");
            emit(SpotifyDefault(state.spotifySettings.copyWith(
                playingOnDeviceId: state.spotifySettings.selectedDeviceId)));
          });
        } on FormatException catch (ex) {
          print(
              "A FormatException related to the SpotifyAPI occurred. This can most likely be ignored: $ex");
        } catch (ex, st) {
          print("exception: $ex with stacktrace $st");
          add(UpdateDeviceList());
          if (ex is AuthorizationException) {
            await userCredentialsStorage.deleteUserCredentials();
            emit(SpotifyError(state.spotifySettings.copyWithoutSpotifyApi(),
                message:
                    "An error occurred while authenticating with the Spotify API. Please re-connect your account."));
          } else {
            emit(SpotifyError(state.spotifySettings,
                message:
                    "Spotify-API rejected playback on selected device. Please make sure the device you selected is online. The player for mobile devices in particular gets disabled very quickly, in which case you need to open the Spotify app to reactivate it."));
          }
          return;
        }
      }
    });
    on<PauseSpotifyPlayback>((event, emit) async {
      if (state.spotifySettings.playingOnDeviceId == null ||
          state.spotifySettings.playingOnDeviceId ==
              SpotifySettingsData.NO_DEVICE) {
        return;
      }
      try {
        await state.spotifySettings.spotifyInterface!.player
            .pause(deviceId: state.spotifySettings.playingOnDeviceId);
        emit(SpotifyDefault(state.spotifySettings
            .copyWith(playingOnDeviceId: SpotifySettingsData.NO_DEVICE)));
      } on FormatException catch (ex) {
        print(
            "A FormatException related to the SpotifyAPI occurred. This can most likely be ignored: $ex");
      } catch (ex, st) {
        print("exception: $ex with stacktrace $st");
        add(UpdateDeviceList());
        if (ex is AuthorizationException) {
          await userCredentialsStorage.deleteUserCredentials();
          emit(SpotifyError(state.spotifySettings.copyWithoutSpotifyApi(),
              message:
                  "An error occurred while authenticating with the Spotify API. Please re-connect your account."));
          return;
        } else {
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

  Future<void> _openExternalUrl(String url) async {
    Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      throw "Invalid uri $url";
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw "Could not launch $url";
    }
  }
}
