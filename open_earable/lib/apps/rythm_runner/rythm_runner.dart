import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_bloc.dart';
import 'package:open_earable/apps/rythm_runner/cards/spotify_card.dart';
import 'package:open_earable/apps/rythm_runner/cards/tracker_card.dart';
import 'package:open_earable/apps/rythm_runner/cards/tracker_settings_card.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class RythmRunner extends StatefulWidget {
  final OpenEarable _openEarable;

  RythmRunner(this._openEarable);

  @override
  _RythmRunnerState createState() => _RythmRunnerState(_openEarable);
}

class _RythmRunnerState extends State<RythmRunner> {
  final OpenEarable _openEarable;

  _RythmRunnerState(this._openEarable);

  @override
  void initState() {
    super.initState();
    BlocProvider.of<SpotifyBloc>(context, listen: false).add(LoadStoredData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text("Rythm Runner"),
      ),
      body: /*_openEarable.bleManager.connected
          ?*/ SingleChildScrollView(
              child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                child: Column(
                  children: [
                    SpotifyCard(),
                    TrackerCard(_openEarable),
                    TrackerSettingsCard(),
                  ],
                ),
              ),
            ))
          /*: EarableNotConnectedWarning()*/,
    );
  }
}
