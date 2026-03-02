import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/model/ppg_filter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/rowling_chart.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:provider/provider.dart';

class HeartTrackerPage extends StatefulWidget {
  final Sensor ppgSensor;

  const HeartTrackerPage({super.key, required this.ppgSensor});

  @override
  State<HeartTrackerPage> createState() => _HeartTrackerPageState();
}

class _HeartTrackerPageState extends State<HeartTrackerPage> {
  late final PpgFilter ppgFilter;

  @override
  void initState() {
    super.initState();

    final sensor = widget.ppgSensor;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SensorConfigurationProvider configProvider = Provider.of<SensorConfigurationProvider>(context, listen: false);
      SensorConfiguration configuration = sensor.relatedConfigurations.first;

      if (configuration is ConfigurableSensorConfiguration &&
          configuration.availableOptions.contains(StreamSensorConfigOption())) {
        configProvider.addSensorConfigurationOption(configuration, StreamSensorConfigOption());
      }

      List<SensorConfigurationValue> values = configProvider.getSensorConfigurationValues(configuration, distinct: true);
      configProvider.addSensorConfiguration(configuration, values.first);
      SensorConfigurationValue selectedValue = configProvider.getSelectedConfigurationValue(configuration)!;
      configuration.setConfiguration(selectedValue);

      double sampleFreq;
      if (selectedValue is SensorFrequencyConfigurationValue) {
        sampleFreq = selectedValue.frequencyHz;
      } else {
        sampleFreq = 25;
      }

      setState(() {
        ppgFilter = PpgFilter(
          inputStream: sensor.sensorStream.asyncMap((data) {
            SensorDoubleValue sensorData = data as SensorDoubleValue;
            return (
              sensorData.timestamp,
              -(sensorData.values[2] + sensorData.values[3])
            );
          }).asBroadcastStream(),
          sampleFreq: sampleFreq,
          timestampExponent: sensor.timestampExponent,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("Heart Tracker"),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: ppgFilterWidget(),
      ),
    );
  }

  Widget ppgFilterWidget() {
    if (!mounted) {
      return Center(child: PlatformCircularProgressIndicator());
    }

    return ListView(
      children: [
        StreamBuilder<double>(
          stream: ppgFilter.heartRateStream,
          builder: (context, snapshot) {
            double bpm = snapshot.data ?? double.nan;
            return Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // BeatingHeart(bpm: bpm.isFinite ? bpm : 60),
                  PlatformText(
                    "${bpm.isNaN ? "--" : bpm.toStringAsFixed(0)} BPM",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          },
        ),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(10),
                child: PlatformText(
                  "Blood Flow",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SizedBox(
                height: 200,
                child: RollingChart(
                  dataSteam: ppgFilter.filteredStream,
                  timestampExponent: widget.ppgSensor.timestampExponent,
                  timeWindow: 5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
