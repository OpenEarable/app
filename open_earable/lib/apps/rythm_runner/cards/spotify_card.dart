import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_bloc.dart';
import 'package:flutter/services.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_settings.dart';
import 'package:open_earable/apps/rythm_runner/bloc/tracker/tracker_bloc.dart';

/// The SpotifyCard is a card widget that allows the user to change the spotify app settings,
/// connect to their Spotify account and select a device for playback used by the step tracker.
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
            // Add Card title and short description
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
            // Build the button to change the Spotify-App-API Settings
            _buildSpotifySettingsButton(),
            // Build the button to connect or disconnect the users spotify account
            _buildSpotifyConnectButton(),
            // Build the Device-Dropdown and Refresh-Button where the user picks which device the music should be played on.
            // We need to wrap this in a BlocBuilder, as the contents of the Dropdown are dependent on the current state.
            BlocBuilder<SpotifyBloc, SpotifyState>(
              builder: (context, state) {
                return _buildDeviceDropdownWithRefresh(
                    context.read<SpotifyBloc>(), state);
              },
            ),
            // Build an error banner, in case an error occured while querying the Spotify-API.
            // Wrap this in BlocBuilder to detect, if we have a SpotifyError state, only then display the banner.
            BlocBuilder<SpotifyBloc, SpotifyState>(
              builder: (context, state) {
                if (state is SpotifyError) {
                  return _buildErrorBanner(state.message);
                }
                return SizedBox(height: 0);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Returns an error banner widget, containing the provided message.
  ///
  /// Args:
  ///   errorMessage (String): Error message, that's supposed to be shown on the banner.
  ///
  /// Returns:
  ///   an error banner widget
  Widget _buildErrorBanner(String errorMessage) {
    return Container(
      color: Colors.red,
      padding: EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Include Error icon
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
              // Make sure the text doesn't overflow to the side if it is too long
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a spotify connect button widget, which enables the user to connect
  /// or to disconnect from their Spotify account.
  ///
  /// Returns:
  ///   a button, which enables the user to connect to Spotify, if they are not already, and to
  ///   disconnect their Spotify account, if they are already connected
  Widget _buildSpotifyConnectButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            // Wrap button in BlocBuilder to access current spotify state and settings.
            // This determines the functionality of the button.
            child: BlocBuilder<SpotifyBloc, SpotifyState>(
              builder: (context, state) {
                return ElevatedButton(
                  // If the Spotify-Interface is present, give Logout functionality
                  onPressed: state.spotifySettings.spotifyInterface != null
                      ? () => _confirmLogout(context)
                      // If no Spotify-Interface is present, check if we have the App API settings
                      : (state.spotifySettings.spotifyClientId != "" &&
                              state.spotifySettings.spotifyClientSecret != "")
                          // If we have the App API settings, request authorization in the browser
                          ? () => context
                              .read<SpotifyBloc>()
                              .add(RequestSpotifyAuth())
                          // If we do not have App API settings, do nothing
                          : null,
                  style: ElevatedButton.styleFrom(
                    // If we have a Spotify-Interface or our App API settings are not present, make button gray, otherwise green
                    backgroundColor: state.spotifySettings.spotifyInterface !=
                                null ||
                            (state.spotifySettings.spotifyClientId == "" ||
                                state.spotifySettings.spotifyClientSecret == "")
                        ? Colors.grey
                        : Color(0xFF1DB954),
                  ),
                  child: Text(
                    // If we hve a Spotify-Interface, display the account we are connected to.
                    state.spotifySettings.spotifyInterface != null
                        ? "Connected account: " +
                            (state.spotifySettings.spotifyName ?? "...")
                        // If not, check if we have App API Settings. If we do, display
                        // "Connect to Spotify", otherwise display "Not available".
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

  /// Returns a button to change the Spotify App API Settings including the Client-ID and Client-Secret.
  /// These settings are accessed by a popup, which the button opens.
  ///
  /// Returns:
  ///   a button, which enables the user to change the Spotify App API Settings
  Widget _buildSpotifySettingsButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            // Wrap in BlocBuilder to access Spotify state and check if we have App Settings already
            child: BlocBuilder<SpotifyBloc, SpotifyState>(
              builder: (context, state) {
                return ElevatedButton(
                  // Open the Settings Popup when the button is pressed
                  onPressed: () => _changeSpotifyApiSettings(context, state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        // Check if we already have App Settings present. If so, make button gray, otherwise green.
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

  /// Displays an alert dialog, which enables the user to change the Spotify App Settings
  ///
  /// Args:
  ///   blocContext (BuildContext): The Spotify BlocContext, which is needed to build the Alert
  ///   state (SpotifyState): The Spotify state, which is needed to access the current settings
  ///
  /// Returns:
  ///   an AlertDialog which enables the user to change the Spotify App API Settings.
  void _changeSpotifyApiSettings(BuildContext blocContext, SpotifyState state) {
    // Controllers for our Input-Fields and the Redirect URL field
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
          // Prevent overflow when editing
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Be sure to know what you are doing before changing anything here! " +
                    "You will need to create an application in the Spotify Developer Dashboard and paste the Client ID and Client Secret here. " +
                    "If you don\'t get redirected to a fitting authorization page when you confirm these options, there is most likely an error in your configuration."),
                SizedBox(height: 16),
                // Build TextField input for the Client-ID
                TextField(
                  controller: clientIdController,
                  decoration: InputDecoration(
                    labelText: "Client ID",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                // Build the TextField input for the Client-Secret
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
                      // Build the non-editable TextField for the Redirect-URI
                      child: TextField(
                        controller: redirectUrlController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: "Redirect URL",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    // Build the copy-to-clipboard button, which helps the user access this info
                    IconButton(
                      icon: Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: redirectUrlController.text));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            // Build the Cancel-Button, which closes the popup
            TextButton(
              child: Text("Cancel"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // Build the Update Settings Button, which triggers the UpdateSpotifyAppSettings event
            TextButton(
              child: Text("Update Settings"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                // Call the UpdateSpotifyAppSettings event with the values of the text fields
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

  /// Displays an alert dialog, which enables the user to disconnect their Spotify account.
  ///
  /// Args:
  ///   blocContext (BuildContext): The Spotify BlocContext, which is needed to build the Alert
  ///
  /// Returns:
  ///   an AlertDialog which enables the user to disconnect their Spotify account.
  void _confirmLogout(BuildContext blocContext) {
    showDialog(
      context: blocContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Unlink"),
          content: Text("Do you want to unlink your spotify account?"),
          actions: <Widget>[
            // Build the Cancel button, which closes the popup
            TextButton(
              child: Text("Cancel"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // Build the unlink button, which deletes the saved 
            //credentials and cancels a possibly running timer.
            TextButton(
              child: Text("Unlink"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                // Call event to delete the stored user credentials.
                blocContext
                    .read<SpotifyBloc>()
                    .add(DeleteSpotifyUserCredentials());
                // Call event to cancel a possibly running timer, 
                // as we have no ability to play music anymore.
                blocContext.read<TrackerBloc>().add(CancelTracking());
                // Close popup.
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Displays a dropdown menu, containing the currently available devices in the connected
  /// Spotify account. If there are no devices available, it displays "No Device".
  ///
  /// Args:
  ///   blocContext (BuildContext): The Spotify BlocContext, which is needed to build the Alert
  ///   state (SpotifyState): The Spotify state, which is needed to access the current settings (devices)
  ///
  /// Returns:
  ///   a Dropdown menu containing the currently avaiable devices and a button to refresh this list
  Widget _buildDeviceDropdownWithRefresh(SpotifyBloc bloc, SpotifyState state) {
    // Use device-ids to identify the devices, as the API takes this value to start playback
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
                  // Change the device id in the settings with UpdateSelectedDevice event
                  onChanged: state.spotifySettings.spotifyInterface != null
                      ? (String? newValue) {
                          // Fire event to update the currently selected device using the new device id 
                          bloc.add(UpdateSelectedDevice(newDeviceId: newValue));
                        }
                      : null,
                  // Use Device-IDs to build the dropdown items, we will retrieve the names later
                  items: deviceIds
                      .map<DropdownMenuItem<String>>((String deviceId) {
                    return DropdownMenuItem<String>(
                      value: deviceId,
                      child: Text(deviceId == SpotifySettingsData.NO_DEVICE
                          ? "No Device"
                          // Try to access the device name in the spotify settings, if not
                          // available, display "Unknown Device", however this should not occur.
                          : state.spotifySettings.idDeviceMap[deviceId]?.name ??
                              "Unknown Device"),
                    );
                  }).toList(),
                  // Make the dropdown fit the card properly
                  isExpanded: true,
                ),
              ),
            ),
          ),
          // build button to refresh the device list
          IconButton(
            icon: Icon(Icons.refresh),
            color: state.spotifySettings.spotifyInterface != null
                ? Colors.white
                : Colors.grey,
                // If we have a Spotify-Interface available, fire UpdateDeviceList event
            onPressed: state.spotifySettings.spotifyInterface != null
                ? () => bloc.add(UpdateDeviceList())
                : null,
          ),
        ],
      ),
    );
  }
}
