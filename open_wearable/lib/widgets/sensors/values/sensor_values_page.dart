import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_card.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Logger _logger = Logger();

class SensorValuesPage extends StatefulWidget {
  const SensorValuesPage({super.key});

  @override
  State<SensorValuesPage> createState() => _SensorValuesPageState();
}

class _SensorValuesPageState extends State<SensorValuesPage> {
  final Map<(Wearable, Sensor), SensorDataProvider> _sensorDataProvider = {};
  AudioRecorder? _audioRecorder; // Separate instance for preview
  bool _isPreviewRecording = false;

  String? _errorMessage;
  InputDevice? _selectedDevice;

  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;

  RecordState _recordState = RecordState.stop;
  final List<double> _waveformData = [];

  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _audioRecorder = AudioRecorder();

      _recordSub = _audioRecorder!.onStateChanged().listen((recordState) {
        if (mounted) {
          setState(() => _recordState = recordState);

          if (recordState == RecordState.stop) {
            _amplitudeSub?.cancel();
            _amplitudeSub = null;
          }
        }
      });

      _initRecording();
    }
  }

  // Add method to check if provider is recording
  bool _isProviderRecording(BuildContext context) {
    try {
      final recorder =
          Provider.of<SensorRecorderProvider>(context, listen: false);
      return recorder.isRecording;
    } catch (e) {
      return false;
    }
  }

  Future<void> _initRecording() async {
    if (!Platform.isAndroid || _audioRecorder == null) return;

    if (_isProviderRecording(context)) {
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    try {
      if (await _audioRecorder!.hasPermission()) {
        await _selectBLEDevice();
        await _startPreview();
      } else {
        final status = await Permission.microphone.request();
        if (status.isGranted) {
          await _selectBLEDevice();
          await _startPreview();
        } else {
          if (mounted) {
            setState(() => _errorMessage = 'Microphone permission denied');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to initialize: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _selectBLEDevice() async {
    if (!Platform.isAndroid || _audioRecorder == null) return;
    try {
      final devices = await _audioRecorder!.listInputDevices();

      // Try to find BLE device
      try {
        _selectedDevice = devices.firstWhere(
          (device) =>
              device.label.toLowerCase().contains('bluetooth') ||
              device.label.toLowerCase().contains('ble') ||
              device.label.toLowerCase().contains('headset') ||
              device.label.toLowerCase().contains('openearable'),
        );
        _logger.i(
            "Auto-selected BLE device for preview: ${_selectedDevice!.label}");
      } catch (e) {
        // No BLE device found
        _selectedDevice = null;
        _logger.e("No BLE headset found");
      }
    } catch (e) {
      _logger.e("Error selecting BLE device: $e");
      _selectedDevice = null;
    }
  }

  Future<String> _getTemporaryPath() async {
    final directory = await getTemporaryDirectory();
    return '${directory.path}/preview_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> _startPreview() async {
    if (!Platform.isAndroid || _audioRecorder == null) return;

    // Don't start if provider is recording
    if (_isProviderRecording(context)) {
      return;
    }

    // Don't start if no BLE device selected
    if (_selectedDevice == null) {
      if (mounted) {
        setState(() => _errorMessage = 'No BLE headset detected');
      }
      return;
    }

    try {
      const encoder = AudioEncoder.wav;

      if (!await _audioRecorder!.isEncoderSupported(encoder)) {
        if (mounted) {
          setState(() => _errorMessage = 'WAV encoder not supported');
        }
        return;
      }

      final path = await _getTemporaryPath();

      final config = RecordConfig(
        encoder: encoder,
        sampleRate: 48000,
        bitRate: 768000,
        numChannels: 1,
        device: _selectedDevice,
      );

      await _audioRecorder!.start(config, path: path);
      await Future.delayed(Duration(milliseconds: 100));

      _amplitudeSub?.cancel();
      _amplitudeSub = _audioRecorder!
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen(
        (amp) {
          if (mounted) {
            setState(() {
              final normalized = (amp.current + 50) / 50;
              _waveformData.add(normalized.clamp(0.0, 2.0));

              if (_waveformData.length > 100) {
                _waveformData.removeAt(0);
              }
            });
          }
        },
        onError: (error) {
          _logger.e("Amplitude stream error: $error");
        },
      );

      if (mounted) {
        setState(() {
          _isPreviewRecording = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      _logger.e("Preview start error: $e");
      if (mounted) {
        setState(() => _errorMessage = 'Failed to start preview: $e');
      }
    }
  }

  Future<void> _stopPreview() async {
    if (!Platform.isAndroid || _audioRecorder == null) return;
    if (!_isPreviewRecording) return;

    try {
      final tempPath = await _audioRecorder!.stop();
      _amplitudeSub?.cancel();
      _amplitudeSub = null;

      if (tempPath != null) {
        try {
          final file = File(tempPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          _logger.e("Error deleting temp preview file: $e");
        }
      }

      if (mounted) {
        setState(() {
          _isPreviewRecording = false;
          _waveformData.clear();
        });
      }
    } catch (e) {
      _logger.e("Error stopping preview: $e");
    }
  }

  @override
  void dispose() {
    // Stop and clean up preview recording
    if (Platform.isAndroid && _audioRecorder != null) {
      if (_recordState != RecordState.stop) {
        _audioRecorder!.stop().then((tempPath) {
          if (tempPath != null) {
            try {
              final file = File(tempPath);
              file.exists().then((exists) {
                if (exists) {
                  file.delete();
                }
              });
            } catch (e) {
              _logger.e("Error deleting temp preview file: $e");
            }
          }
        });
      }

      _recordSub?.cancel();
      _amplitudeSub?.cancel();
      _audioRecorder!.dispose();
    }

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
        // Stop preview if provider starts recording
        if (Platform.isAndroid &&
            recorderProvider.isRecording &&
            _isPreviewRecording) {
          _stopPreview();
        }
        // Restart preview if provider stops recording
        else if (Platform.isAndroid &&
            !recorderProvider.isRecording &&
            !_isPreviewRecording &&
            _audioRecorder != null) {
          _initRecording();
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
              else if (_isPreviewRecording || _isInitializing)
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
                                painter: WaveformPainter(_waveformData),
                              ),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: PlatformText(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
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
            else if (_isPreviewRecording || _isInitializing)
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
                      CustomPaint(
                        size: Size(double.infinity, 80),
                        painter: WaveformPainter(_waveformData),
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
