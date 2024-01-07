import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_bloc.dart';
import 'package:flutter/services.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_settings.dart';
import 'package:open_earable/apps/rythm_runner/bloc/tracker/tracker_bloc.dart';

class SpotifyCard extends StatelessWidget {
  const SpotifyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Spotify Settings",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
                "Link to your Spotify account. Make sure you are conntected to WIFI. If playback doesn\'t start, open the Spotify app to reactivate the player.",
                style: TextStyle(
                  color: Color.fromRGBO(168, 168, 172, 1.0),
                  fontSize: 15.0,
                  fontStyle: FontStyle.italic,
                )),
            SizedBox(height: 0),
            _buildSpotifySettingsButton(),
            _buildSpotifyConnectButton(),
            BlocBuilder<SpotifyBloc, SpotifyState>(
              builder: (context, state) {
                return _buildDeviceDropdownWithRefresh(
                    context.read<SpotifyBloc>(), state);
              },
            ),
            BlocBuilder<SpotifyBloc, SpotifyState>(
              builder: (context, state) {
                if(state is SpotifyError) {
                  return _buildErrorBanner(
                    state.message);
                }
                return SizedBox(height: 0);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String errorMessage) {
    return Container(
      color: Colors.red,
      padding: EdgeInsets.all(8.0),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.white,
          ),
          SizedBox(width: 8.0),
          Flexible(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.0,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotifyConnectButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: BlocBuilder<SpotifyBloc, SpotifyState>(
              builder: (context, state) {
                return ElevatedButton(
                  onPressed: state.spotifySettings.spotifyInterface != null
                      ? () => _confirmLogout(context)
                      : (state.spotifySettings.spotifyClientId != "" &&
                              state.spotifySettings.spotifyClientSecret != "")
                          ? () => context
                              .read<SpotifyBloc>()
                              .add(RequestSpotifyAuth())
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.spotifySettings.spotifyInterface !=
                                null ||
                            (state.spotifySettings.spotifyClientId == "" ||
                                state.spotifySettings.spotifyClientSecret == "")
                        ? Colors.grey
                        : Color(0xFF1DB954),
                  ),
                  child: Text(
                    state.spotifySettings.spotifyInterface != null
                        ? "Connected account: " +
                            (state.spotifySettings.spotifyName ?? "...")
                        : (state.spotifySettings.spotifyClientId != "" &&
                                state.spotifySettings.spotifyClientSecret != "")
                            ? "Connect to Spotify"
                            : "Not available",
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotifySettingsButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: BlocBuilder<SpotifyBloc, SpotifyState>(
              builder: (context, state) {
                return ElevatedButton(
                  onPressed: () => _changeSpotifyApiSettings(context, state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (state.spotifySettings.spotifyClientId == "" ||
                                state.spotifySettings.spotifyClientSecret == "")
                            ? Color(0xFF1DB954)
                            : Colors.grey,
                  ),
                  child: Text(
                    "Change Spotify settings",
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _changeSpotifyApiSettings(BuildContext blocContext, SpotifyState state) {
    TextEditingController clientIdController =
        TextEditingController(text: state.spotifySettings.spotifyClientId);
    TextEditingController clientSecretController =
        TextEditingController(text: state.spotifySettings.spotifyClientSecret);
    TextEditingController redirectUrlController =
        TextEditingController(text: state.spotifySettings.redirectUrl);

    showDialog(
      context: blocContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Update Spotify App Settings"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Be sure to know what you are doing before changing anything here! " +
                    "You will need to create an application in the Spotify Developer Dashboard and paste the Client ID and Client Secret here. " +
                    "If you don\'t get redirected to a fitting authorization page when you confirm these options, there is most likely an error in your configuration."),
                SizedBox(height: 16),
                TextField(
                  controller: clientIdController,
                  decoration: InputDecoration(
                    labelText: "Client ID",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: clientSecretController,
                  decoration: InputDecoration(
                    labelText: "Client Secret",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                    "You will need to add this Redirect URL to your Spotify Application in the Spotify Developer Dashboard:"),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: redirectUrlController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: "Redirect URL",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(
                                ClipboardData(text: redirectUrlController.text))
                            .then((_) {
                          /*_showSnackBarText(context,
                              "Redirect URL has been copied to clipboard");*/
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Update Settings"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                BlocProvider.of<SpotifyBloc>(blocContext).add(
                    UpdateSpotifyAppSettings(
                        clientId: clientIdController.text,
                        clientSecret: clientSecretController.text));
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmLogout(BuildContext blocContext) {
    showDialog(
      context: blocContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Unlink"),
          content: Text("Do you want to unlink your spotify account?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Unlink"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                blocContext
                    .read<SpotifyBloc>()
                    .add(DeleteSpotifyUserCredentials());
                blocContext.read<TrackerBloc>().add(CancelTracking());
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceDropdownWithRefresh(SpotifyBloc bloc, SpotifyState state) {
    Set<String> deviceIds = Set.from([
      SpotifySettingsData.NO_DEVICE,
      ...state.spotifySettings.idDeviceMap.keys
    ]);
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 5, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 5, 0, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: DropdownButton<String>(
                  value: state.spotifySettings.selectedDeviceId,
                  onChanged: state.spotifySettings.spotifyInterface != null
                      ? (String? newValue) {
                          bloc.add(UpdateSelectedDevice(newDeviceId: newValue));
                        }
                      : null,
                  items: deviceIds
                      .map<DropdownMenuItem<String>>((String deviceId) {
                    return DropdownMenuItem<String>(
                      value: deviceId,
                      child: Text(deviceId == SpotifySettingsData.NO_DEVICE
                          ? "No Device"
                          : state.spotifySettings.idDeviceMap[deviceId]?.name ??
                              "Unknown Device"),
                    );
                  }).toList(),
                  isExpanded: true,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            color: state.spotifySettings.spotifyInterface != null
                ? Colors.white
                : Colors.grey,
            onPressed: state.spotifySettings.spotifyInterface != null
                ? () => bloc.add(UpdateDeviceList())
                : null,
          ),
        ],
      ),
    );
  }
}
