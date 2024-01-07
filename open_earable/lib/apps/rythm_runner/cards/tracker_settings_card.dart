import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/tracker/tracker_bloc.dart';

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
            Padding(
                padding: EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildThresholdInput(
                        parameter: ThresholdParameter.X,
                      ),
                      SizedBox(width: 16),
                      _buildThresholdInput(
                        parameter: ThresholdParameter.Z,
                      ),
                      SizedBox(width: 16),
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

  Widget _buildThresholdInput({required ThresholdParameter parameter}) {
    return Column(
      children: [
        Text(
          parameter.parameterName,
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 8),
        SizedBox(
            width: 60,
            child: BlocBuilder<TrackerBloc, TrackerState>(
              builder: (context, state) {
                return Column(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () => parameter.modifyParameterValue(
                          context.read<TrackerBloc>(), state, 0.5),
                    ),
                    Text(
                      parameter.getParameterValue(state).toString(),
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    ),
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

enum ThresholdParameter {
  X("X-Threshold"),
  Z("Z-Threshold"),
  XZ("XZ-Threshold");

  final String parameterName;

  const ThresholdParameter(this.parameterName);

  void modifyParameterValue(
      TrackerBloc bloc, TrackerState state, double modifyBy) {
    switch (this) {
      case ThresholdParameter.X:
        bloc.add(UpdateTrackerSettings(
            config: state.config
                .copyWith(xThreshold: state.config.xThreshold + modifyBy)));
        break;
      case ThresholdParameter.Z:
        bloc.add(UpdateTrackerSettings(
            config: state.config
                .copyWith(zThreshold: state.config.zThreshold + modifyBy)));
        break;
      case ThresholdParameter.XZ:
        bloc.add(UpdateTrackerSettings(
            config: state.config
                .copyWith(xzThreshold: state.config.xzThreshold + modifyBy)));
        break;
    }
  }

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
