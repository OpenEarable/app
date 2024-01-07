import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_settings.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:open_earable/apps/rythm_runner/bloc/tracker/tracker_bloc.dart';

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
                    child: BlocBuilder<TrackerBloc, TrackerState>(
                      builder: (context, state) {
                        return Text(
                          state.runData.bpmAverage.toString() + " BPM",
                          style: TextStyle(
                              fontFamily: "Digital",
                              fontSize: 80,
                              fontWeight: FontWeight.normal,
                              color: state is TrackerFinishedState
                                  ? Colors.lightBlue
                                  : Colors.white),
                        );
                      },
                    )),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: BlocBuilder<TrackerBloc, TrackerState>(
                        builder: (context, state) {
                          return BlocBuilder<SpotifyBloc, SpotifyState>(
                            builder: (spotifyContext, spotifyState) {
                              return ElevatedButton(
                                onPressed: _openEarable.bleManager.connected &&
                                        spotifyState.spotifySettings
                                                .selectedDeviceId !=
                                            SpotifySettingsData.NO_DEVICE
                                    ? () => toggleRecording(
                                        context.read<TrackerBloc>(), state)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(200, 36),
                                  backgroundColor:
                                      _openEarable.bleManager.connected &&
                                              spotifyState.spotifySettings
                                                      .selectedDeviceId !=
                                                  SpotifySettingsData.NO_DEVICE
                                          ? (state is TrackerRunningState
                                              ? Color(0xfff27777)
                                              : Color(0xFF1DB954))
                                          : Colors.grey,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  _openEarable.bleManager.connected
                                      ? (state is TrackerRunningState
                                          ? _formatDuration(
                                              state.runData.duration)
                                          : "Start tracking")
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
                Padding(
                  padding: EdgeInsets.all(5),
                  child: BlocBuilder<TrackerBloc, TrackerState>(
                    builder: (context, state) {
                      return Text(
                        "Step Count: ${state.runData.stepCount}",
                        style: TextStyle(fontSize: 20),
                      );
                    },
                  ),
                ),
                // for debugging
                /*Padding( 
                  padding: EdgeInsets.all(5),
                  child: BlocBuilder<TrackerBloc, TrackerState>(
                    builder: (context, state) {
                      return IconButton(
                          onPressed: () =>
                              context.read<TrackerBloc>().add(TrackStep()),
                          icon: Icon(Icons.plus_one));
                    },
                  ),
                ),*/
              ],
            ),
          ],
        ),
      ),
    );
  }

  void toggleRecording(TrackerBloc bloc, TrackerState state) {
    if (state is TrackerIdleState || state is TrackerFinishedState) {
      bloc.add(StartTracking());
    } else if (state is TrackerRunningState) {
      bloc.add(CancelTracking());
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
