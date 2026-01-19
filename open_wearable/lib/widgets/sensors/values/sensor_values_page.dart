import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_card.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class SensorValuesPage extends StatefulWidget {
  final Map<(Wearable, Sensor), SensorDataProvider>? sharedProviders;

  const SensorValuesPage({
    super.key,
    this.sharedProviders,
  });

  @override
  State<SensorValuesPage> createState() => _SensorValuesPageState();
}

class _SensorValuesPageState extends State<SensorValuesPage>
    with AutomaticKeepAliveClientMixin<SensorValuesPage> {
  final Map<(Wearable, Sensor), SensorDataProvider> _ownedProviders = {};

  Map<(Wearable, Sensor), SensorDataProvider> get _sensorDataProvider =>
      widget.sharedProviders ?? _ownedProviders;

  bool get _ownsProviders => widget.sharedProviders == null;

  // Audio State
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
  bool get wantKeepAlive => true;

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
          // Automatically select BLE headset
          _selectedDevice = _devices.firstWhere(
            (device) =>
                device.label.toLowerCase().contains('bluetooth') ||
                device.label.toLowerCase().contains('ble') ||
                device.label.toLowerCase().contains('headset'),
            orElse: () =>
                _devices.isNotEmpty ? _devices.first : null as InputDevice,
          );
          if (_selectedDevice != null) {
            print("Auto-selected BLE device: ${_selectedDevice?.label}");
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
    if (_ownsProviders) {
      for (final provider in _ownedProviders.values) {
        provider.dispose();
      }
      _ownedProviders.clear();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<bool>(
      valueListenable: AppShutdownSettings.disableLiveDataGraphsListenable,
      builder: (context, disableLiveDataGraphs, _) {
        return ValueListenableBuilder<bool>(
          valueListenable:
              AppShutdownSettings.hideLiveDataGraphsWithoutDataListenable,
          builder: (context, hideCardsWithoutLiveData, __) {
            final shouldHideCardsWithoutLiveData =
                hideCardsWithoutLiveData && !disableLiveDataGraphs;
            return Consumer<WearablesProvider>(
              builder: (context, wearablesProvider, child) {
                return FutureBuilder<List<WearableDisplayGroup>>(
                  future: buildWearableDisplayGroups(
                    wearablesProvider.wearables,
                    shouldCombinePair: (left, right) =>
                        wearablesProvider.isStereoPairCombined(
                      first: left,
                      second: right,
                    ),
                  ),
                  builder: (context, snapshot) {
                    final groups = orderWearableGroupsByNameAndSide(
                      snapshot.data ??
                          wearablesProvider.wearables
                              .map(
                                (wearable) => WearableDisplayGroup.single(
                                  wearable: wearable,
                                ),
                              )
                              .toList(),
                    );
                    final orderedWearables =
                        _orderedWearablesFromGroups(groups);
                    _ensureProviders(orderedWearables);
                    _cleanupProviders(orderedWearables);

                    Widget buildContent() {
                      final hasAnySensors = _hasAnySensors(orderedWearables);
                      final charts = _buildCharts(
                        orderedWearables,
                        hideCardsWithoutLiveData:
                            shouldHideCardsWithoutLiveData,
                      );

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 600) {
                            return _buildSmallScreenLayout(
                              context,
                              charts,
                              hasAnySensors: hasAnySensors,
                              hideCardsWithoutLiveData:
                                  shouldHideCardsWithoutLiveData,
                            );
                          } else {
                            return _buildLargeScreenLayout(
                              context,
                              charts,
                              hasAnySensors: hasAnySensors,
                              hideCardsWithoutLiveData:
                                  shouldHideCardsWithoutLiveData,
                            );
                          }
                        },
                      );
                    }

                    if (disableLiveDataGraphs) {
                      return buildContent();
                    }

                    final sensorDataListenable =
                        Listenable.merge(_providersFor(orderedWearables));

                    return AnimatedBuilder(
                      animation: sensorDataListenable,
                      builder: (context, ___) => buildContent(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _ensureProviders(List<Wearable> orderedWearables) {
    for (final wearable in orderedWearables) {
      if (!wearable.hasCapability<SensorManager>()) {
        continue;
      }
      for (final sensor
          in wearable.requireCapability<SensorManager>().sensors) {
        _sensorDataProvider.putIfAbsent(
          (wearable, sensor),
          () => SensorDataProvider(
            wearable: wearable,
            sensor: sensor,
          ),
        );
      }
    }
  }

  Iterable<SensorDataProvider> _providersFor(
    List<Wearable> orderedWearables,
  ) sync* {
    for (final wearable in orderedWearables) {
      if (!wearable.hasCapability<SensorManager>()) {
        continue;
      }
      for (final sensor
          in wearable.requireCapability<SensorManager>().sensors) {
        final provider = _sensorDataProvider[(wearable, sensor)];
        if (provider != null) {
          yield provider;
        }
      }
    }
  }

  bool _hasAnySensors(List<Wearable> orderedWearables) {
    return orderedWearables.any(
      (wearable) =>
          wearable.hasCapability<SensorManager>() &&
          wearable.requireCapability<SensorManager>().sensors.isNotEmpty,
    );
  }

  List<Widget> _buildCharts(
    List<Wearable> orderedWearables, {
    required bool hideCardsWithoutLiveData,
  }) {
    final charts = <Widget>[];
    for (final wearable in orderedWearables) {
      if (!wearable.hasCapability<SensorManager>()) {
        continue;
      }
      for (final sensor
          in wearable.requireCapability<SensorManager>().sensors) {
        final provider = _sensorDataProvider[(wearable, sensor)];
        if (provider == null) {
          continue;
        }
        if (hideCardsWithoutLiveData && provider.sensorValues.isEmpty) {
          continue;
        }
        final chartIdentity = _sensorChartIdentity(
          wearable: wearable,
          sensor: sensor,
        );
        charts.add(
          ChangeNotifierProvider.value(
            key: ValueKey(chartIdentity),
            value: provider,
            child: SensorValueCard(
              sensor: sensor,
              wearable: wearable,
            ),
          ),
        );
      }
    }
    return charts;
  }

  String _sensorChartIdentity({
    required Wearable wearable,
    required Sensor sensor,
  }) {
    final axisNames = sensor.axisNames.join(',');
    final axisUnits = sensor.axisUnits.join(',');
    return '${wearable.deviceId}|${sensor.runtimeType}|${sensor.sensorName}|$axisNames|$axisUnits';
  }

  void _cleanupProviders(List<Wearable> orderedWearables) {
    if (!_ownsProviders) {
      return;
    }
    _sensorDataProvider.removeWhere((key, provider) {
      final keepProvider = orderedWearables.any(
        (device) =>
            device.hasCapability<SensorManager>() &&
            device == key.$1 &&
            device.requireCapability<SensorManager>().sensors.contains(key.$2),
      );
      if (!keepProvider) {
        provider.dispose();
      }
      return !keepProvider;
    });
  }

  List<Wearable> _orderedWearablesFromGroups(
    List<WearableDisplayGroup> groups,
  ) {
    final ordered = <Wearable>[];
    for (final group in groups) {
      final left = group.leftDevice;
      final right = group.rightDevice;
      if (left != null) {
        ordered.add(left);
      }
      if (right != null && right.deviceId != left?.deviceId) {
        ordered.add(right);
      }
      if (left == null && right == null) {
        ordered.addAll(group.members);
      }
    }
    return ordered;
  }

  Widget _buildAudioUI() {
    return Column(
      children: [
        if (_devices.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Text('Input: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<InputDevice>(
                      value: _selectedDevice,
                      isExpanded: true,
                      items: _devices
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d.label)))
                          .toList(),
                      onChanged: _changeDevice,
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.refresh), onPressed: _loadDevices),
                ],
              ),
            ),
          ),
        if (_isRecording)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                size: const Size(double.infinity, 100),
                painter: WaveformPainter(_waveformData),
              ),
            ),
          )
        else if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PlatformText(_errorMessage!,
                style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSmallScreenLayout(
    BuildContext context,
    List<Widget> charts, {
    required bool hasAnySensors,
    required bool hideCardsWithoutLiveData,
  }) {
    return ListView(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      children: [
        _buildAudioUI(),
        ...charts,
        if (charts.isEmpty)
          Center(
            child: _buildEmptyStateCard(
              context,
              _resolveEmptyState(
                  hasAnySensors: hasAnySensors,
                  hideCardsWithoutLiveData: hideCardsWithoutLiveData),
            ),
          ),
      ],
    );
  }

  Widget _buildLargeScreenLayout(
    BuildContext context,
    List<Widget> charts, {
    required bool hasAnySensors,
    required bool hideCardsWithoutLiveData,
  }) {
    return SingleChildScrollView(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      child: Column(
        children: [
          _buildAudioUI(),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 500,
              childAspectRatio: 1.5,
              crossAxisSpacing: SensorPageSpacing.gridGap,
              mainAxisSpacing: SensorPageSpacing.gridGap,
            ),
            itemCount: charts.isEmpty ? 1 : charts.length,
            itemBuilder: (context, index) {
              if (charts.isEmpty) {
                return _buildEmptyStateCard(
                  context,
                  _resolveEmptyState(
                      hasAnySensors: hasAnySensors,
                      hideCardsWithoutLiveData: hideCardsWithoutLiveData),
                );
              }
              return charts[index];
            },
          ),
        ],
      ),
    );
  }

  _SensorValuesEmptyState _resolveEmptyState({
    required bool hasAnySensors,
    required bool hideCardsWithoutLiveData,
  }) {
    if (hasAnySensors && hideCardsWithoutLiveData) {
      return const _SensorValuesEmptyState(
        icon: Icons.sensors_outlined,
        title: 'Waiting for live sensor data',
        subtitle:
            'Graphs will appear once your sensors stream their first samples.',
        removeCardBackground: true,
      );
    }

    return const _SensorValuesEmptyState(
      icon: Icons.sensors_off_outlined,
      title: 'No sensors connected',
      subtitle: 'Connect a wearable to start viewing live sensor values.',
    );
  }

  Widget _buildEmptyStateCard(
    BuildContext context,
    _SensorValuesEmptyState emptyState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final removeCardBackground = emptyState.removeCardBackground;

    return Card(
      color: removeCardBackground ? Colors.transparent : null,
      clipBehavior: Clip.antiAlias,
      elevation: removeCardBackground ? 0 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: removeCardBackground
            ? BorderSide.none
            : BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
      ),
      shadowColor: removeCardBackground ? Colors.transparent : null,
      surfaceTintColor: removeCardBackground ? Colors.transparent : null,
      child: Ink(
        decoration: removeCardBackground
            ? null
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.28),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  ],
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    emptyState.icon,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                PlatformText(
                  emptyState.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                PlatformText(
                  emptyState.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SensorValuesEmptyState {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool removeCardBackground;

  const _SensorValuesEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.removeCardBackground = false,
  });
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
