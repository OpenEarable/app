import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_card.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class SensorValuesPage extends StatefulWidget {
  const SensorValuesPage({super.key});

  @override
  State<SensorValuesPage> createState() => _SensorValuesPageState();
}

class _SensorValuesPageState extends State<SensorValuesPage> {
  final Map<(Wearable, Sensor), SensorDataProvider> _sensorDataProvider = {};

  String? _errorMessage;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _checkStreamingStatus();
    }
  }

  void _checkStreamingStatus() {
    final recorderProvider =
        Provider.of<SensorRecorderProvider>(context, listen: false);
    if (!recorderProvider.isBLEMicrophoneStreamingEnabled) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'BLE microphone streaming not enabled. Enable it in sensor configuration.';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = null;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose all sensor data providers
    for (var provider in _sensorDataProvider.values) {
      provider.dispose();
    }
    _sensorDataProvider.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WearablesProvider, SensorRecorderProvider>(
      builder: (context, wearablesProvider, recorderProvider, child) {
        // Update error message if streaming status changes
        if (Platform.isAndroid && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!recorderProvider.isBLEMicrophoneStreamingEnabled &&
                _errorMessage == null &&
                !recorderProvider.isRecording) {
              setState(() {
                _errorMessage =
                    'BLE microphone streaming not enabled. Enable it in sensor configuration.';
              });
            } else if (recorderProvider.isBLEMicrophoneStreamingEnabled &&
                _errorMessage != null &&
                _errorMessage!
                    .contains('BLE microphone streaming not enabled')) {
              setState(() {
                _errorMessage = null;
              });
            }
          });
        }
        List<Widget> charts = [];

        for (var wearable in wearablesProvider.wearables) {
          if (wearable.hasCapability<SensorManager>()) {
            for (Sensor sensor
                in wearable.requireCapability<SensorManager>().sensors) {
              if (!_sensorDataProvider.containsKey((wearable, sensor))) {
                _sensorDataProvider[(wearable, sensor)] =
                    SensorDataProvider(sensor: sensor);
              }
              charts.add(
                ChangeNotifierProvider.value(
                  value: _sensorDataProvider[(wearable, sensor)],
                  child: SensorValueCard(
                    sensor: sensor,
                    wearable: wearable,
                  ),
                ),
              );
            }
          }
        }

        _sensorDataProvider.removeWhere(
          (key, _) => !wearablesProvider.wearables.any(
            (device) =>
                device.hasCapability<SensorManager>() &&
                device == key.$1 &&
                device
                    .requireCapability<SensorManager>()
                    .sensors
                    .contains(key.$2),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildSmallScreenLayout(context, charts, recorderProvider);
            } else {
              return _buildLargeScreenLayout(context, charts, recorderProvider);
            }
          },
        );
      },
    );
  }

  Widget _buildSmallScreenLayout(
    BuildContext context,
    List<Widget> charts,
    SensorRecorderProvider recorderProvider,
  ) {
    final showRecorderWaveform = recorderProvider.isRecording;
    return SingleChildScrollView(
      padding: EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (charts.isEmpty)
            Center(
              child: PlatformText(
                "No sensors connected",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            )
          else ...[
            if (Platform.isAndroid) ...[
              if (showRecorderWaveform)
                // Use waveform from SensorRecorderProvider when recording
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.fiber_manual_record,
                                color: Colors.red, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'AUDIO WAVEFORM',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomPaint(
                          size: Size(double.infinity, 100),
                          painter:
                              WaveformPainter(recorderProvider.waveformData),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUDIO WAVEFORM',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        _isInitializing
                            ? SizedBox(
                                height: 100,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : CustomPaint(
                                size: Size(double.infinity, 100),
                                painter: WaveformPainter(
                                    recorderProvider.waveformData),
                              ),
                      ],
                    ),
                  ),
                ),
            ],
            ListView(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: charts,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLargeScreenLayout(
    BuildContext context,
    List<Widget> charts,
    SensorRecorderProvider recorderProvider,
  ) {
    final showRecorderWaveform = recorderProvider.isRecording;

    return SingleChildScrollView(
      padding: EdgeInsets.all(10),
      child: Column(
        children: [
          if (Platform.isAndroid) ...[
            if (showRecorderWaveform)
              // Use waveform from SensorRecorderProvider when recording
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color: Colors.red,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Audio waveform (Recording)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CustomPaint(
                        size: Size(double.infinity, 80),
                        painter: WaveformPainter(recorderProvider.waveformData),
                      ),
                    ],
                  ),
                ),
              )
            else if (recorderProvider.isBLEMicrophoneStreamingEnabled ||
                _isInitializing)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio waveform',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _isInitializing
                          ? SizedBox(
                              height: 80,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : CustomPaint(
                              size: Size(double.infinity, 80),
                              painter: WaveformPainter(
                                  recorderProvider.waveformData),
                            ),
                    ],
                  ),
                ),
              ),
            if (_errorMessage != null)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: PlatformText(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
          ],
          // Sensor charts grid
          GridView.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 500,
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: charts.isEmpty ? 1 : charts.length,
            itemBuilder: (context, index) {
              if (charts.isEmpty) {
                return Card(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: Colors.grey,
                      width: 1,
                      style: BorderStyle.solid,
                      strokeAlign: -1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: PlatformText(
                      "No sensors available",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                );
              }
              return charts[index];
            },
          ),
        ],
      ),
    );
  }
}

// Custom waveform painter with vertical bars
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color waveColor;
  final double spacing;
  final double waveThickness;
  final bool showMiddleLine;

  WaveformPainter(
    this.waveformData, {
    this.waveColor = Colors.blue,
    this.spacing = 4.0,
    this.waveThickness = 3.0,
    this.showMiddleLine = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final double height = size.height;
    final double centerY = height / 2;

    // Draw middle line first (behind the bars)
    if (showMiddleLine) {
      final centerLinePaint = Paint()
        ..color = Colors.grey.withAlpha(75)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        centerLinePaint,
      );
    }

    // Paint for the vertical bars
    final paint = Paint()
      ..color = waveColor
      ..strokeWidth = waveThickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Calculate how many bars can fit in the available width
    final maxBars = (size.width / spacing).floor();
    final startIndex =
        waveformData.length > maxBars ? waveformData.length - maxBars : 0;

    // Calculate starting position (always start at 0 or align right)
    final visibleData = waveformData.sublist(startIndex);
    final totalWaveformWidth = visibleData.length * spacing;
    final startX = size.width - totalWaveformWidth;

    // Draw each amplitude value as a vertical bar
    for (int i = 0; i < visibleData.length; i++) {
      final x = startX + (i * spacing);
      final amplitude = visibleData[i];

      // Scale amplitude to fit within the canvas height
      final barHeight = amplitude * centerY * 0.8;

      // Draw top half of the bar (above center line)
      final topY = centerY - barHeight;
      final bottomY = centerY + barHeight;

      // Draw the vertical line from top to bottom
      canvas.drawLine(
        Offset(x, topY),
        Offset(x, bottomY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.waveformData.length != waveformData.length ||
        oldDelegate.waveColor != waveColor;
  }
}
