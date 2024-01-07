import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_settings.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:open_earable/apps/rythm_runner/bloc/tracker/tracker_bloc.dart';

/// The TrackerCard is a card widget that allows the user to start or stop the tracking
/// of their running speed. It displays the current BPM/SPM and the total step count.
class TrackerCard extends StatelessWidget {
  final OpenEarable _openEarable;

  const TrackerCard(this._openEarable);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add title and short description
            Text(
              "Track Running Speed",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
                "Run at a constant rate for 30 seconds. Check if the steps are counted accurately. If not, try adjusting the settings below.",
                style: TextStyle(
                  color: Color.fromRGBO(168, 168, 172, 1.0),
                  fontSize: 15.0,
                  fontStyle: FontStyle.italic,
                )),
            SizedBox(height: 0),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    // Wrap in BlocBuilder to retrieve the current BPM average value through the state
                    child: BlocBuilder<TrackerBloc, TrackerState>(
                      builder: (context, state) {
                        // Display the current BPM(/SPM) count with same style as in recorder app
                        return Text(
                          state.runData.bpmAverage.toString() + " BPM",
                          style: TextStyle(
                              fontFamily: "Digital",
                              fontSize: 80,
                              fontWeight: FontWeight.normal,
                              // If the tracking was completed (not cancelled), 
                              // we display the final value in light blue.
                              color: state is TrackerFinishedState
                                  ? Colors.lightBlue
                                  : Colors.white),
                        );
                      },
                    )),
                // Build the Start/Cancel Tracking button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      // Wrap in BlocBuilder for TrackerBloc to access the tracker events and data
                      child: BlocBuilder<TrackerBloc, TrackerState>(
                        builder: (context, state) {
                          // Also wrap in BlocBuilder for SpotifyBloc to access spotify settings
                          return BlocBuilder<SpotifyBloc, SpotifyState>(
                            builder: (spotifyContext, spotifyState) {
                              // Build the Start/Cancel Tracking button
                              return ElevatedButton(
                                // Chck if the earable is connected and we 
                                // selected a device to play the music on.
                                onPressed: _openEarable.bleManager.connected &&
                                        spotifyState.spotifySettings
                                                .selectedDeviceId !=
                                            SpotifySettingsData.NO_DEVICE
                                    // if so, toggle recording
                                    ? () => toggleRecording(
                                        context.read<TrackerBloc>(), state)
                                    // otherwise do nothing
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(200, 36),
                                  backgroundColor:
                                  // Check if the erable is connected and we selected a device to play the music on
                                      _openEarable.bleManager.connected &&
                                              spotifyState.spotifySettings
                                                      .selectedDeviceId !=
                                                  SpotifySettingsData.NO_DEVICE
                                          // If so, check if the tracker is running
                                          ? (state is TrackerRunningState
                                              // If it is, display button in red, otherwise green
                                              ? Color(0xfff27777)
                                              : Color(0xFF1DB954))
                                          // If we do not have a connected earable or a 
                                          // selected device, display button in grey.
                                          : Colors.grey,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  // Check if we have a connected erable
                                  _openEarable.bleManager.connected
                                      // If so, check if the tracker is running
                                      ? (state is TrackerRunningState
                                          // If it is, display the remaining time
                                          ? _formatDuration(
                                              state.runData.duration)
                                          // Otherwise display "Start tracking"
                                          : "Start tracking")
                                      // If no erable is detected, display "No earable detected"
                                      : "No earable detected",
                                  style: TextStyle(fontSize: 20),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Display total step count
                Padding(
                  padding: EdgeInsets.all(5),
                  // Wrap in BlocBuilder to get current step count from state
                  child: BlocBuilder<TrackerBloc, TrackerState>(
                    builder: (context, state) {
                      // Simply display the total step count. This is not
                      // directly linked to the BPM, as we use a moving 
                      // average to calculate that. However, as we track
                      // for 30 seconds, the resulting BPM should be around
                      // double of this value.
                      return Text(
                        "Step Count: ${state.runData.stepCount}",
                        style: TextStyle(fontSize: 20),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle the current state, if we are tracking, stop the tracking, if we are not, start it. 
  /// This is achieved by calling the corresponding events.
  /// 
  /// Args:
  ///   bloc (TrackerBloc): Instance of the TrackerBloc on which we call our events.
  ///   state (TrackerState): The Tracker state, which is needed to access the current state type
  void toggleRecording(TrackerBloc bloc, TrackerState state) {
    // If state is idle or finished, start tracking
    if (state is TrackerIdleState || state is TrackerFinishedState) {
      bloc.add(StartTracking());
    // If it is running, cancel the tracking
    } else if (state is TrackerRunningState) {
      bloc.add(CancelTracking());
    }
    // Otherwise ignore
  }

  /// Retrieved from recorder app in here, formats a duration into a nice format.
  /// 
  /// Args:
  ///   duration (Duration): The duration we want to format
  /// 
  /// Returns:
  ///   The given duration in a String formatted in the following way: "MM:SS"
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
