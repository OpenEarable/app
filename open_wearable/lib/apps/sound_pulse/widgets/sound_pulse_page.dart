import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/model/ppg_filter.dart';
import 'package:open_wearable/apps/sound_pulse/model/sound_player.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:provider/provider.dart';

enum OffsetMode { absolute, percentual }

class SoundPulsePage extends StatefulWidget {
  final Sensor ppgSensor;

  const SoundPulsePage({super.key, required this.ppgSensor});

  @override
  State<SoundPulsePage> createState() => _SoundPulsePageState();
}

class _SoundPulsePageState extends State<SoundPulsePage> {
  late final PpgFilter ppgFilter;
  late final SoundPlayer soundPlayer;
  double offsetBpm = 0.0; // Offset in BPM
  double offsetPercent = 0.0; // Offset in percent
  OffsetMode offsetMode = OffsetMode.absolute;
  bool isPlaying = false;
  bool isInitialized = false;
  Stopwatch stopwatch = Stopwatch();
  int durationMinutes = 0;
  int durationSeconds = 0;
  Timer? _timer;
  TextEditingController minController = TextEditingController(text: '0');
  TextEditingController secController = TextEditingController(text: '0');
  String selectedSound = 'beep.mp3';
  static const List<String> availableSounds = ['beep.mp3', 'beep2.mp3', 'beep3.mp3'];

  @override
  void initState() {
    super.initState();
    soundPlayer = SoundPlayer(soundAsset: 'lib/apps/sound_pulse/assets/$selectedSound');
    isInitialized = false;

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
        isInitialized = true;
      });
    });
  }

  @override
  void dispose() {
    soundPlayer.dispose();
    _timer?.cancel();
    minController.dispose();
    secController.dispose();
    super.dispose();
  }

  void _togglePlay(double bpm) {
    if (isPlaying) {
      soundPlayer.stop();
      _timer?.cancel();
      stopwatch.stop();
      setState(() => isPlaying = false);
    } else {
      double effectiveBpm;
      if (offsetMode == OffsetMode.absolute) {
        effectiveBpm = bpm + offsetBpm;
      } else {
        effectiveBpm = bpm * (1 + offsetPercent / 100);
      }
      if (effectiveBpm > 0) {
        double intervalMs = (60 / effectiveBpm) * 1000;
        soundPlayer.start(intervalMs);
        stopwatch.reset();
        stopwatch.start();
        _timer = Timer.periodic(Duration(seconds: 1), (timer) {
          setState(() {});
          int elapsed = stopwatch.elapsed.inSeconds;
          int totalDuration = durationMinutes * 60 + durationSeconds;
          if (elapsed >= totalDuration && totalDuration > 0) {
            soundPlayer.playOnce('lib/apps/sound_pulse/assets/timer_done.mp3');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Timer done!", style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            _togglePlay(bpm);
          }
        });
        setState(() => isPlaying = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return PlatformScaffold(
        appBar: PlatformAppBar(title: PlatformText("Sound Pulse")),
        body: Center(child: PlatformCircularProgressIndicator()),
      );
    }
    return PlatformScaffold(
      appBar: PlatformAppBar(title: PlatformText("Sound Pulse")),
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PlatformText(
                        "${bpm.isNaN ? "--" : bpm.toStringAsFixed(0)} BPM",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  IgnorePointer(
                    ignoring: isPlaying,
                    child: Opacity(
                      opacity: isPlaying ? 0.5 : 1.0,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Radio<OffsetMode>(
                                value: OffsetMode.absolute,
                                groupValue: offsetMode,
                                onChanged: (value) => setState(() => offsetMode = value!),
                              ),
                              PlatformText("Absolute"),
                              SizedBox(width: 20),
                              Radio<OffsetMode>(
                                value: OffsetMode.percentual,
                                groupValue: offsetMode,
                                onChanged: (value) => setState(() => offsetMode = value!),
                              ),
                              PlatformText("Percentual"),
                            ],
                          ),
                          SizedBox(height: 20),
                          if (offsetMode == OffsetMode.absolute) ...[
                            PlatformText("Offset (BPM): ${offsetBpm.toInt()}"),
                            Slider(
                              value: offsetBpm,
                              min: -30,
                              max: 30,
                              divisions: 60,
                              onChanged: (value) {
                                setState(() => offsetBpm = value);
                                if (isPlaying && !bpm.isNaN) {
                                  double effectiveBpm = bpm + offsetBpm;
                                  if (effectiveBpm > 0) {
                                    double intervalMs = (60 / effectiveBpm) * 1000;
                                    soundPlayer.updateInterval(intervalMs);
                                  }
                                }
                              },
                            ),
                          ] else ...[
                            PlatformText("Offset (%): ${offsetPercent.toInt()}"),
                            Slider(
                              value: offsetPercent,
                              min: -50,
                              max: 50,
                              divisions: 100,
                              onChanged: (value) {
                                setState(() => offsetPercent = value);
                                if (isPlaying && !bpm.isNaN) {
                                  double effectiveBpm = bpm * (1 + offsetPercent / 100);
                                  if (effectiveBpm > 0) {
                                    double intervalMs = (60 / effectiveBpm) * 1000;
                                    soundPlayer.updateInterval(intervalMs);
                                  }
                                }
                              },
                            ),
                          ],
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PlatformText("Sound: "),
                              DropdownButton<String>(
                                value: selectedSound,
                                items: availableSounds.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => selectedSound = v);
                                    soundPlayer.changeSound(v);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: PlatformText("Elapsed Time: ${isPlaying ? '${stopwatch.elapsed.inMinutes.toString().padLeft(2, '0')}:${(stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}' : '00:00'}"),
                    ),
                  ),
                  SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        children: [
                          PlatformText("Set Duration"),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: PlatformTextField(
                                  controller: minController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  enabled: !isPlaying,
                                  onChanged: (v) {
                                    int val = int.tryParse(v) ?? 0;
                                    if (val < 0) val = 0;
                                    if (val > 999) val = 999; // arbitrary max
                                    setState(() => durationMinutes = val);
                                    minController.text = val.toString();
                                    minController.selection = TextSelection.fromPosition(TextPosition(offset: minController.text.length));
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              PlatformText("min"),
                              SizedBox(width: 20),
                              Expanded(
                                child: PlatformTextField(
                                  controller: secController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  enabled: !isPlaying,
                                  onChanged: (v) {
                                    int val = int.tryParse(v) ?? 0;
                                    if (val < 0) val = 0;
                                    if (val > 59) val = 59;
                                    setState(() => durationSeconds = val);
                                    secController.text = val.toString();
                                    secController.selection = TextSelection.fromPosition(TextPosition(offset: secController.text.length));
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              PlatformText("sec"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  PlatformElevatedButton(
                    material: (_, __) => MaterialElevatedButtonData(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPlaying ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    onPressed: bpm.isNaN ? null : () => _togglePlay(bpm),
                    child: PlatformText(isPlaying ? "Stop" : "Start"),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
