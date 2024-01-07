import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/tracker/tracker_bloc.dart';

/// The TrackerSettingsCard is a card widget that allows the user to fine tune
/// the pedometer settings (thresholds), so the steps are counted accurately.
class TrackerSettingsCard extends StatelessWidget {
  const TrackerSettingsCard({super.key});

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
              "Step Counter Settings",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
                "Adjust these settings if steps are not counted accurately. It is recommended to make symmetrical adjustments (if you modify x, modify z too).",
                style: TextStyle(
                  color: Color.fromRGBO(168, 168, 172, 1.0),
                  fontSize: 15.0,
                  fontStyle: FontStyle.italic,
                )),
            SizedBox(height: 0),
            // Add the treshold toggles for all parameter types (X, Z, X+Z)
            Padding(
                padding: EdgeInsets.all(16),
                // Scroll-View to prevent overflow on small devices
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Build toggle for X
                      _buildThresholdInput(
                        parameter: ThresholdParameter.X,
                      ),
                      SizedBox(width: 16),
                      // Build toggle for Z
                      _buildThresholdInput(
                        parameter: ThresholdParameter.Z,
                      ),
                      SizedBox(width: 16),
                      // Build toggle for X+Z
                      _buildThresholdInput(
                        parameter: ThresholdParameter.XZ,
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// Returns a widget, which contains a label with the given parameter name, a text displaying the
  /// current value of the corresponding parameter and two buttons to change the parameters value.
  /// 
  /// Args:
  ///   parameter (ThresholdParameter): Enum detailing the parameter which is to be modified by this toggle
  /// 
  /// Returns:
  ///   a toggle for the given parameter, including title, current value, and buttons to modify the value
  Widget _buildThresholdInput({required ThresholdParameter parameter}) {
    return Column(
      children: [
        // Display title of the given parameter
        Text(
          parameter.parameterName,
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 8),
        SizedBox(
            width: 60,
            // Wrap in BlocBuilder to access the tracker parameters and call modification event
            child: BlocBuilder<TrackerBloc, TrackerState>(
              builder: (context, state) {
                return Column(
                  children: [
                    // Build "plus" button, which increases the parameters value by .5
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () => parameter.modifyParameterValue(
                          context.read<TrackerBloc>(), state, 0.5),
                    ),
                    // Build text, which displays the parameters current value
                    Text(
                      parameter.getParameterValue(state).toString(),
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    ),
                    // Build "minus" button, which decreases the parameters value by .5
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () => parameter.modifyParameterValue(
                          context.read<TrackerBloc>(), state, -0.5),
                    ),
                  ],
                );
              },
            )),
      ],
    );
  }
}

/// This enum helps represent and modify the different thresholds for the pedometer.
enum ThresholdParameter {
  X("X-Threshold"),
  Z("Z-Threshold"),
  XZ("XZ-Threshold");

  final String parameterName;

  const ThresholdParameter(this.parameterName);

  /// The function modifies a specific parameter value in the TrackerBloc based on the provided modifyBy
  /// value.
  /// 
  /// Args:
  ///   bloc (TrackerBloc): Instance of the TrackerBloc, which is used to call the UpdateTrackerSettings event
  ///   state (TrackerState): State parameter to access the current threshold values
  ///   modifyBy (double): The value by which the parameters value is to be changed
  void modifyParameterValue(
      TrackerBloc bloc, TrackerState state, double modifyBy) {
    switch (this) {
      case ThresholdParameter.X:
      // Update treshold for X
        bloc.add(UpdateTrackerSettings(
            config: state.config
                .copyWith(xThreshold: state.config.xThreshold + modifyBy)));
        break;
      case ThresholdParameter.Z:
      // Update treshold for Z
        bloc.add(UpdateTrackerSettings(
            config: state.config
                .copyWith(zThreshold: state.config.zThreshold + modifyBy)));
        break;
      case ThresholdParameter.XZ:
      // Update treshold for X+Z
        bloc.add(UpdateTrackerSettings(
            config: state.config
                .copyWith(xzThreshold: state.config.xzThreshold + modifyBy)));
        break;
    }
  }

  /// Returns the current value of the parameter based on the state
  /// 
  /// Args:
  ///   state (TrackerState): State parameter is used to acces the current threshold values
  /// 
  /// Returns:
  ///   The current threshold value as a double
  double getParameterValue(TrackerState state) {
    switch (this) {
      case ThresholdParameter.X:
        return state.config.xThreshold;
      case ThresholdParameter.Z:
        return state.config.zThreshold;
      case ThresholdParameter.XZ:
        return state.config.xzThreshold;
    }
  }
}
