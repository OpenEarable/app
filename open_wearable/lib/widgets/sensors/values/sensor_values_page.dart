import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_card.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SensorValuesPage extends StatefulWidget {
  const SensorValuesPage({super.key});

  @override
  State<SensorValuesPage> createState() => _SensorValuesPageState();
}

class _SensorValuesPageState extends State<SensorValuesPage> {
  final Map<(Wearable, Sensor), SensorDataProvider> _sensorDataProvider = {};
  late final AudioRecorder _audioRecorder;

  bool _isRecording = false;
  String? _errorMessage;
  List<InputDevice> _devices = [];
  InputDevice? _selectedDevice;

  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;

  RecordState _recordState = RecordState.stop;
  List<double> _waveformData = [];
  Amplitude? _amplitude;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();

    // Only subscribe to state changes initially
    _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
      if (mounted) {
        setState(() => _recordState = recordState);

        // Clean up amplitude subscription when recording stops
        if (recordState == RecordState.stop) {
          _amplitudeSub?.cancel();
          _amplitudeSub = null;
        }
      }
    });

    _initRecording();
  }

  Future<void> _initRecording() async {
    print("Initializing audio recorder");

    try {
      if (await _audioRecorder.hasPermission()) {
        print("Permission granted");
        await _loadDevices();
        await _startRecording();
      } else {
        print("No permission, requesting...");
        final status = await Permission.microphone.request();
        if (status.isGranted) {
          await _loadDevices();
          await _startRecording();
        } else {
          if (mounted) {
            setState(() => _errorMessage = 'Microphone permission denied');
          }
        }
      }
    } catch (e) {
      print("Init error: $e");
      if (mounted) {
        setState(() => _errorMessage = 'Failed to initialize: $e');
      }
    }
  }

  Future<void> _loadDevices() async {
    try {
      final devs = await _audioRecorder.listInputDevices();
      if (mounted) {
        setState(() {
          _devices = devs;
          if (_selectedDevice == null && _devices.isNotEmpty) {
            _selectedDevice = _devices.first;
            print("Selected device: ${_selectedDevice?.label}");
          }
        });
      }
    } catch (e) {
      print("Error loading devices: $e");
    }
  }

  Future<String> _getRecordingPath() async {
    final directory = await getTemporaryDirectory();
    return '${directory.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> _startRecording() async {
    try {
      const encoder = AudioEncoder.aacLc;

      if (!await _audioRecorder.isEncoderSupported(encoder)) {
        if (mounted) {
          setState(() => _errorMessage = 'Encoder not supported');
        }
        return;
      }

      final path = await _getRecordingPath();

      final config = RecordConfig(
        encoder: encoder,
        numChannels: 1,
        device: _selectedDevice,
      );

      await _audioRecorder.start(config, path: path);

      // Wait a bit to ensure recording is active
      await Future.delayed(Duration(milliseconds: 100));

      _amplitudeSub?.cancel();
      // Subscribe to amplitude changes after recording started
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen(
        (amp) {
          if (mounted) {
            setState(() {
              _amplitude = amp;
              // Add normalized amplitude to waveform data
              final normalized = (amp.current + 50) / 50;
              _waveformData.add(normalized.clamp(0.0, 2.0));

              // Keep only last 100 samples
              if (_waveformData.length > 100) {
                _waveformData.removeAt(0);
              }
            });
          }
        },
        onError: (error) {
          print("Amplitude stream error: $error");
        },
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print("Recording start error: $e");
      if (mounted) {
        setState(() => _errorMessage = 'Failed to start recording: $e');
      }
    }
  }

  Future<void> _changeDevice(InputDevice? device) async {
    if (device == null) return;

    // Stop current recording
    if (_recordState != RecordState.stop) {
      await _audioRecorder.stop();
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
    }

    // Update selected device and restart
    if (mounted) {
      setState(() {
        _selectedDevice = device;
        _waveformData.clear();
        _isRecording = false;
      });
    }

    await _startRecording();
  }

  @override
  void dispose() {
    _audioRecorder.stop();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();

    // Dispose all sensor data providers
    for (var provider in _sensorDataProvider.values) {
      provider.dispose();
    }
    _sensorDataProvider.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WearablesProvider>(
      builder: (context, wearablesProvider, child) {
        List<Widget> charts = [];

        for (var wearable in wearablesProvider.wearables) {
          if (wearable is SensorManager) {
            for (Sensor sensor in (wearable as SensorManager).sensors) {
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

        // Proper cleanup with disposal
        final keysToRemove = _sensorDataProvider.keys
            .where(
              (key) => !wearablesProvider.wearables.any((device) =>
                  device is SensorManager &&
                  device == key.$1 &&
                  (device as SensorManager).sensors.contains(key.$2)),
            )
            .toList();

        for (var key in keysToRemove) {
          _sensorDataProvider[key]?.dispose();
          _sensorDataProvider.remove(key);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildSmallScreenLayout(context, charts);
            } else {
              return _buildLargeScreenLayout(context, charts);
            }
          },
        );
      },
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context, List<Widget> charts) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        children: [
          // Device selector
          if (_devices.isNotEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Text('Input: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<InputDevice>(
                        value: _selectedDevice,
                        isExpanded: true,
                        items: _devices.map((d) {
                          return DropdownMenuItem<InputDevice>(
                            value: d,
                            child: Text(d.label),
                          );
                        }).toList(),
                        onChanged: _changeDevice,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: _loadDevices,
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 10),

          // Custom waveform widget
          if (_isRecording)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CustomPaint(
                  size: Size(double.infinity, 100),
                  painter: WaveformPainter(_waveformData),
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
          if (_isRecording || _errorMessage != null) SizedBox(height: 10),

          // Sensor charts
          Expanded(
            child: charts.isEmpty
                ? Center(
                    child: PlatformText(
                      "No sensors connected",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  )
                : ListView(children: charts),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context, List<Widget> charts) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(10),
      child: Column(
        children: [
          // Device selector for large screens
          if (_devices.isNotEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Input Device: ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(width: 12),
                    DropdownButton<InputDevice>(
                      value: _selectedDevice,
                      items: _devices.map((d) {
                        return DropdownMenuItem<InputDevice>(
                          value: d,
                          child: Text(d.label),
                        );
                      }).toList(),
                      onChanged: _changeDevice,
                    ),
                    SizedBox(width: 12),
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: _loadDevices,
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 10),

          // Audio waveform for large screens
          if (_isRecording)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CustomPaint(
                  size: Size(double.infinity, 80),
                  painter: WaveformPainter(_waveformData),
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
          if (_isRecording || _errorMessage != null) SizedBox(height: 10),

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

    // Calculate starting position to align bars from right
    final totalWaveformWidth = waveformData.length * spacing;
    final startX = size.width - totalWaveformWidth;

    // Draw each amplitude value as a vertical bar
    for (int i = 0; i < waveformData.length; i++) {
      final x = startX + (i * spacing);
      final amplitude = waveformData[i];

      // Scale amplitude to fit within the canvas height
      // Amplitude is normalized to 0-2 range, scale it to use 80% of half height
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
