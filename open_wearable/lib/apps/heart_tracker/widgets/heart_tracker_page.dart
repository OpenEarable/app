import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/model/band_pass_filter.dart';
import 'package:open_wearable/apps/heart_tracker/model/high_pass_filter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/rowling_chart.dart';

class HeartTrackerPage extends StatelessWidget {
  final Sensor ppgSensor;

  HeartTrackerPage({super.key, required this.ppgSensor}) {
    SensorConfiguration configuration = ppgSensor.relatedConfigurations.first;
    if (configuration is StreamableSensorConfiguration) {
      (configuration as StreamableSensorConfiguration).streamData = true;
    }
    configuration.setConfiguration(configuration.values.first);
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("Heart Tracker"),
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 300,
            child: RollingChart(
              dataSteam: highPassFilterTupleStream(
                input: ppgSensor.sensorStream.asyncMap(
                  (data) {
                    return (data.timestamp, (data as SensorDoubleValue).values[2]);
                  }
                ),
                cutoffFreq: 0.5,
                sampleFreq: 25,
              ),
              timestampExponent: ppgSensor.timestampExponent,
              timeWindow: 5,
            ),
          ),
        ],
      ),
    );
  }

  Stream<(int, double)> highPassFilterTupleStream({
    required Stream<(int, double)> input,
    required double cutoffFreq,
    required double sampleFreq,
  }) {
    final filter = BandPassFilter(
      sampleFreq: 25.0,
      lowCut: 0.5,
      highCut: 3,
    );

    return input.map((event) {
      final (timestamp, rawValue) = event;
      final filteredValue = filter.filter(rawValue);
      return (timestamp, filteredValue);
    });
  }
}