import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/sensor_streams.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/stereo_position_badge.dart';
import 'package:provider/provider.dart';

class SelfTestPage extends StatefulWidget {
  final Wearable wearable;
  final SensorConfigurationProvider sensorConfigProvider;

  const SelfTestPage({
    super.key,
    required this.wearable,
    required this.sensorConfigProvider,
  });

  @override
  State<SelfTestPage> createState() => _SelfTestPageState();
}

class _SelfTestPageState extends State<SelfTestPage> {
  static const double _minimumTestDataCollectionSeconds = 3.0;
  static const double _ledBrightnessFactor = 0.2;

  late final List<_TestSpec> _tests;
  late final Map<String, Sensor?> _sensorByTestId;

  final Map<String, _TestResult> _resultsByTestId = {};
  final Map<SensorConfiguration, SensorConfigurationValue?>
      _savedConfigurations = {};

  WearablesProvider? _wearablesProvider;
  StreamSubscription<SensorValue>? _sensorSubscription;
  Timer? _timeoutTimer;
  Timer? _autoAdvanceTimer;
  bool _hasDisabledSensorsAfterCompletion = false;
  int _postCheckTransitionToken = 0;

  int _currentTestIndex = 0;
  _TestAnalyzer? _currentAnalyzer;
  bool _isRunning = false;
  int? _firstTimestamp;
  int _sampleIndex = 0;
  bool _isInitializingSensor = false;
  String _liveHint = '';
  List<_ChartPoint> _liveCurve = const [];

  @override
  void initState() {
    super.initState();

    _tests = [
      _TestSpec(
        id: 'accelerometer',
        title: 'Accelerometer',
        description:
            'Shake the device a few times. This verifies non-static acceleration in m/s².',
        timeout: const Duration(seconds: 16),
        targetFrequencyHz: 50,
      ),
      _TestSpec(
        id: 'gyroscope',
        title: 'Gyroscope',
        description:
            'Rotate or shake the device repeatedly. This verifies angular-rate response.',
        timeout: const Duration(seconds: 16),
        targetFrequencyHz: 50,
      ),
      _TestSpec(
        id: 'magnetometer',
        title: 'Magnetometer',
        description:
            'Move or rotate the device near metal or a small magnet. This verifies magnetic-field response.',
        timeout: const Duration(seconds: 16),
        targetFrequencyHz: 25,
      ),
      _TestSpec(
        id: 'barometer',
        title: 'Barometer',
        description:
            'Blow steadily into the device for about one second to create a pressure change.',
        timeout: const Duration(seconds: 18),
        targetFrequencyHz: 25,
      ),
      _TestSpec(
        id: 'temperature',
        title: 'Temperature Sensor',
        description:
            'Touch the sensor with a finger. Expected valid range is 30 to 40 °C.',
        timeout: const Duration(seconds: 16),
        targetFrequencyHz: 10,
      ),
      _TestSpec(
        id: 'ppg',
        title: 'PPG',
        description:
            'Place the PPG area on a finger and hold still for around 10 seconds. The app looks for a pulse pattern.',
        timeout: const Duration(seconds: 30),
        targetFrequencyHz: 50,
      ),
    ];

    _sensorByTestId = _resolveSensorsForTests(widget.wearable);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<WearablesProvider>();
    if (!identical(provider, _wearablesProvider)) {
      _wearablesProvider?.removeListener(_onWearablesChanged);
      _wearablesProvider = provider;
      _wearablesProvider?.addListener(_onWearablesChanged);
    }
  }

  @override
  void dispose() {
    _wearablesProvider?.removeListener(_onWearablesChanged);
    _stopCurrentRun();
    _autoAdvanceTimer?.cancel();
    _restoreSavedConfigurations();
    unawaited(_resetLedColor());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<WearablesProvider>().wearables.any(
          (wearable) => wearable.deviceId == widget.wearable.deviceId,
        );
    final total = _tests.length;
    final completed = _resultsByTestId.length;
    final passed =
        _resultsByTestId.values.where((result) => result.passed).length;
    final currentSpec = _tests[_currentTestIndex];
    final currentResult = _resultsByTestId[currentSpec.id];
    final currentSensor = _sensorByTestId[currentSpec.id];

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Device Self Test'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          _OverviewCard(
            wearable: widget.wearable,
            completed: completed,
            total: total,
            passed: passed,
            connected: connected,
            tests: _tests,
            resultsByTestId: _resultsByTestId,
            currentSpec: currentSpec,
            running: _isRunning,
            initializing: _isInitializingSensor,
            currentHasSensor: currentSensor != null,
            currentResult: currentResult,
            onStartPressed: connected ? _startCurrentTest : null,
            onNextPressed: _canGoNext() ? _goToNextTest : null,
            onRetryPressed: connected ? _retryCurrentTest : null,
            onRunAllAgainPressed: completed == total ? _resetAllTests : null,
          ),
          const SizedBox(height: 12),
          _CurrentTestCard(
            spec: currentSpec,
            sensor: currentSensor,
            running: _isRunning,
            initializing: _isInitializingSensor,
            liveHint: _liveHint,
            liveCurve: _liveCurve,
            result: currentResult,
          ),
          const SizedBox(height: 12),
          _ResultsCard(
            tests: _tests,
            resultsByTestId: _resultsByTestId,
            running: _isRunning || _isInitializingSensor,
            onRetryTest: connected ? _retryTestById : null,
          ),
        ],
      ),
    );
  }

  Map<String, Sensor?> _resolveSensorsForTests(Wearable wearable) {
    final result = <String, Sensor?>{
      for (final test in _tests) test.id: null,
    };

    if (!wearable.hasCapability<SensorManager>()) {
      return result;
    }

    final sensors = wearable.requireCapability<SensorManager>().sensors;

    Sensor? findByKeywords(List<String> keywords) {
      final lowered =
          keywords.map((k) => k.toLowerCase()).toList(growable: false);
      for (final sensor in sensors) {
        final text = '${sensor.sensorName} ${sensor.chartTitle}'.toLowerCase();
        if (lowered.any(text.contains)) {
          return sensor;
        }
      }
      return null;
    }

    String normalizeToken(String input) {
      final normalized = input
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      return normalized.replaceAll(RegExp(r'^_|_$'), '');
    }

    Sensor? findByPreferredName(List<String> preferredNames) {
      final preferred = preferredNames.map(normalizeToken).toSet();
      for (final sensor in sensors) {
        final sensorName = normalizeToken(sensor.sensorName);
        final chartName = normalizeToken(sensor.chartTitle);
        if (preferred.contains(sensorName) || preferred.contains(chartName)) {
          return sensor;
        }
      }
      return null;
    }

    result['accelerometer'] = findByKeywords(['accelerometer', 'acc']);
    result['gyroscope'] = findByKeywords(['gyroscope', 'gyro']);
    result['magnetometer'] = findByKeywords([
      'magnetometer',
      'magnetic',
      'mag',
    ]);
    result['barometer'] = findByKeywords(['barometer', 'pressure', 'baro']);
    result['temperature'] =
        findByPreferredName(['OPTICAL_TEMPERATURE_SENSOR']) ??
            findByKeywords(['temperature', 'temp']);
    result['ppg'] = findByKeywords(['ppg', 'photopleth', 'pulse']);

    return result;
  }

  void _onWearablesChanged() {
    if (!mounted || !_isRunning) {
      return;
    }
    final provider = _wearablesProvider;
    if (provider == null) {
      return;
    }
    final connected = provider.wearables.any(
      (wearable) => wearable.deviceId == widget.wearable.deviceId,
    );
    if (!connected) {
      _completeCurrentTest(
        passed: false,
        message: 'Connection lost while running this test.',
      );
    }
  }

  Future<void> _startCurrentTest() async {
    if (_isRunning || _isInitializingSensor) {
      return;
    }
    _postCheckTransitionToken++;
    _autoAdvanceTimer?.cancel();
    unawaited(_setLedColor(r: 255, g: 255, b: 255));

    final spec = _tests[_currentTestIndex];
    final sensor = _sensorByTestId[spec.id];
    if (sensor == null) {
      _registerTestFailure(
        testId: spec.id,
        message: 'Required sensor is not available on this device.',
      );
      return;
    }

    final analyzer = _createAnalyzerFor(spec, sensor);
    if (analyzer == null) {
      _registerTestFailure(
        testId: spec.id,
        message: 'This test is not supported for the selected sensor setup.',
      );
      return;
    }

    try {
      await _prepareSensorForStreaming(
        sensor,
        targetFrequencyHz: spec.targetFrequencyHz,
      );
    } catch (_) {
      _registerTestFailure(
        testId: spec.id,
        message: 'Unable to configure sensor streaming for this test.',
      );
      return;
    }

    _stopCurrentRun();

    setState(() {
      _isRunning = true;
      _currentAnalyzer = analyzer;
      _firstTimestamp = null;
      _sampleIndex = 0;
      _liveHint = analyzer.liveStatus;
      _liveCurve = const [];
      _resultsByTestId.remove(spec.id);
    });

    _sensorSubscription = SensorStreams.shared(sensor).listen(
      (value) => _onSensorValue(value, sensor: sensor, spec: spec),
      onError: (_) {
        _completeCurrentTest(
          passed: false,
          message: 'Sensor stream failed while running this test.',
        );
      },
    );

    _timeoutTimer = Timer(spec.timeout, () {
      final analyzerAtTimeout = _currentAnalyzer;
      if (!_isRunning || analyzerAtTimeout == null) {
        return;
      }
      _completeCurrentTest(
        passed: false,
        message: analyzerAtTimeout.failureMessage(timedOut: true),
      );
    });
  }

  Future<void> _prepareSensorForStreaming(
    Sensor sensor, {
    required int targetFrequencyHz,
  }) async {
    for (final config in sensor.relatedConfigurations) {
      _savedConfigurations.putIfAbsent(
        config,
        () => widget.sensorConfigProvider.getSelectedConfigurationValue(config),
      );

      if (config is ConfigurableSensorConfiguration &&
          config.availableOptions
              .any((option) => option is StreamSensorConfigOption)) {
        widget.sensorConfigProvider.addSensorConfigurationOption(
          config,
          const StreamSensorConfigOption(),
          markPending: false,
        );
      }

      final availableValues = widget.sensorConfigProvider
          .getSensorConfigurationValues(config, distinct: true);
      if (availableValues.isEmpty) {
        continue;
      }

      final selected = _selectBestValue(
        availableValues,
        targetFrequencyHz: targetFrequencyHz,
      );
      widget.sensorConfigProvider.addSensorConfiguration(
        config,
        selected,
        markPending: false,
      );
      config.setConfiguration(selected);
    }
  }

  SensorConfigurationValue _selectBestValue(
    List<SensorConfigurationValue> values, {
    required int targetFrequencyHz,
  }) {
    if (values.length == 1) {
      return values.first;
    }

    if (values.first is! SensorFrequencyConfigurationValue) {
      return values.first;
    }

    SensorFrequencyConfigurationValue? nextBigger;
    SensorFrequencyConfigurationValue? maxValue;

    for (final value in values.whereType<SensorFrequencyConfigurationValue>()) {
      if (maxValue == null || value.frequencyHz > maxValue.frequencyHz) {
        maxValue = value;
      }

      if (value.frequencyHz >= targetFrequencyHz &&
          (nextBigger == null || value.frequencyHz < nextBigger.frequencyHz)) {
        nextBigger = value;
      }
    }

    return nextBigger ?? maxValue ?? values.first;
  }

  _TestAnalyzer? _createAnalyzerFor(_TestSpec spec, Sensor sensor) {
    switch (spec.id) {
      case 'accelerometer':
        return _MotionAnalyzer(
          unitLabel: sensor.axisUnits.firstOrNull ?? 'm/s²',
          movementLabel: 'shake',
          minimumEvents: 3,
          deltaThreshold: 4.2,
          minimumStdDev: 1.1,
          minimumSamples: 24,
          highThreshold: null,
          lowThreshold: null,
        );
      case 'gyroscope':
        return _MotionAnalyzer(
          unitLabel: sensor.axisUnits.firstOrNull ?? '°/s',
          movementLabel: 'rotation',
          minimumEvents: 3,
          deltaThreshold: 45,
          minimumStdDev: 18,
          minimumSamples: 24,
          highThreshold: 120,
          lowThreshold: 40,
        );
      case 'magnetometer':
        return _MagnetometerAnalyzer(
          unitLabel: sensor.axisUnits.firstOrNull ?? 'uT',
        );
      case 'barometer':
        return _BarometerAnalyzer(
          unitLabel: sensor.axisUnits.firstOrNull ?? 'Pa',
        );
      case 'temperature':
        return _TemperatureAnalyzer(
          unitLabel: sensor.axisUnits.firstOrNull ?? '°C',
        );
      case 'ppg':
        return _PpgAnalyzer();
      default:
        return null;
    }
  }

  void _onSensorValue(
    SensorValue value, {
    required Sensor sensor,
    required _TestSpec spec,
  }) {
    if (!_isRunning) {
      return;
    }

    final analyzer = _currentAnalyzer;
    if (analyzer == null) {
      return;
    }

    final sampleValues = _valuesFromSensorValue(value);
    if (sampleValues.isEmpty) {
      return;
    }

    _firstTimestamp ??= value.timestamp;
    final timeSeconds = (value.timestamp - _firstTimestamp!) *
        pow(10, sensor.timestampExponent).toDouble();

    final sample = _SensorSample(
      timeSeconds: timeSeconds,
      values: sampleValues,
    );

    analyzer.addSample(sample);
    final primaryValue = analyzer.primaryValue(sample);
    final plotX = _sampleIndex.toDouble();
    _sampleIndex += 1;
    final minDurationReached =
        sample.timeSeconds >= _minimumTestDataCollectionSeconds;
    final remainingSeconds =
        (_minimumTestDataCollectionSeconds - sample.timeSeconds)
            .clamp(0.0, _minimumTestDataCollectionSeconds);
    final nextLiveHint = analyzer.hasPassed && !minDurationReached
        ? '${analyzer.liveStatus} Criteria reached. Collecting for ${remainingSeconds.toStringAsFixed(1)} s more.'
        : analyzer.liveStatus;
    final nextCurve = _appendCurvePoint(
      _liveCurve,
      _ChartPoint(plotX, primaryValue),
      maxPoints: 180,
    );

    setState(() {
      _liveCurve = nextCurve;
      _liveHint = nextLiveHint;
    });

    if (analyzer.hasPassed && minDurationReached) {
      _completeCurrentTest(
        passed: true,
        message: analyzer.successMessage,
      );
      return;
    }

    final thisTestResult = _resultsByTestId[spec.id];
    if (thisTestResult != null) {
      return;
    }
  }

  List<double> _valuesFromSensorValue(SensorValue value) {
    if (value is SensorDoubleValue) {
      return value.values;
    }
    if (value is SensorIntValue) {
      return value.values.map((v) => v.toDouble()).toList(growable: false);
    }
    return value.valueStrings
        .map(double.tryParse)
        .whereType<double>()
        .toList(growable: false);
  }

  List<_ChartPoint> _appendCurvePoint(
    List<_ChartPoint> curve,
    _ChartPoint point, {
    required int maxPoints,
  }) {
    final next = List<_ChartPoint>.from(curve)..add(point);
    if (next.length <= maxPoints) {
      return next;
    }
    return next.sublist(next.length - maxPoints);
  }

  void _completeCurrentTest({
    required bool passed,
    required String message,
  }) {
    final completedIndex = _currentTestIndex;
    final completedSpec = _tests[completedIndex];
    final curve = _downsampleCurve(_liveCurve, maxPoints: 90);
    _stopCurrentRun();

    if (!mounted) {
      return;
    }

    late final bool allCompleted;
    setState(() {
      _resultsByTestId[completedSpec.id] = _TestResult(
        passed: passed,
        message: message,
        curve: curve,
      );
      _liveHint = '';
      _liveCurve = const [];
      allCompleted = _resultsByTestId.length >= _tests.length;
    });

    if (!passed) {
      unawaited(_setLedColor(r: 255, g: 0, b: 0));
    }

    unawaited(
      _runPostCheckTransition(
        completedSpec: completedSpec,
        completedIndex: completedIndex,
        passed: passed,
        allCompleted: allCompleted,
      ),
    );
  }

  void _registerTestFailure({
    required String testId,
    required String message,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _resultsByTestId[testId] = _TestResult(
        passed: false,
        message: message,
        curve: const [],
      );
      _liveHint = '';
      _liveCurve = const [];
    });
    unawaited(_setLedColor(r: 255, g: 0, b: 0));
  }

  void _stopCurrentRun() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _currentAnalyzer = null;
    _firstTimestamp = null;
    _sampleIndex = 0;
    _isRunning = false;
  }

  Future<void> _runPostCheckTransition({
    required _TestSpec completedSpec,
    required int completedIndex,
    required bool passed,
    required bool allCompleted,
  }) async {
    final token = ++_postCheckTransitionToken;

    await _disableSensorForSpec(completedSpec);
    if (!mounted || token != _postCheckTransitionToken) {
      return;
    }

    if (allCompleted) {
      final allPassed =
          _tests.every((test) => _resultsByTestId[test.id]?.passed == true);
      await _setLedColor(
        r: allPassed ? 0 : 255,
        g: allPassed ? 255 : 0,
        b: 0,
      );
      await _disableSensorsAfterCompletion();
      return;
    }

    if (!passed) {
      return;
    }

    final nextIndex = _nextTestIndexAfter(completedIndex);
    if (nextIndex == null) {
      return;
    }
    await _showCooldownAndMoveTo(nextIndex, token: token);
  }

  Future<void> _disableSensorForSpec(_TestSpec spec) async {
    final sensor = _sensorByTestId[spec.id];
    if (sensor == null) {
      return;
    }

    for (final config in sensor.relatedConfigurations) {
      try {
        final offValue = config.offValue;
        if (offValue != null) {
          widget.sensorConfigProvider.addSensorConfiguration(
            config,
            offValue,
            markPending: false,
          );
          config.setConfiguration(offValue);
          continue;
        }

        if (config is ConfigurableSensorConfiguration &&
            config.availableOptions
                .any((option) => option is StreamSensorConfigOption)) {
          widget.sensorConfigProvider.removeSensorConfigurationOption(
            config,
            const StreamSensorConfigOption(),
            markPending: false,
          );
          final selected =
              widget.sensorConfigProvider.getSelectedConfigurationValue(config);
          if (selected is ConfigurableSensorConfigurationValue) {
            config.setConfiguration(selected);
          }
        }
      } catch (_) {
        // Continue with remaining configs even if one write fails.
      }
    }
  }

  Future<void> _showCooldownAndMoveTo(
    int nextIndex, {
    required int token,
  }) async {
    if (!mounted || token != _postCheckTransitionToken) {
      return;
    }

    setState(() {
      _currentTestIndex = nextIndex;
      _isInitializingSensor = true;
      _liveHint = '';
      _liveCurve = const [];
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted || token != _postCheckTransitionToken) {
      return;
    }

    setState(() {
      _isInitializingSensor = false;
    });
    _autoStartCurrentTestIfPossible();
  }

  int? _nextTestIndexAfter(int fromIndex) {
    for (int i = fromIndex + 1; i < _tests.length; i++) {
      if (!_resultsByTestId.containsKey(_tests[i].id)) {
        return i;
      }
    }
    return null;
  }

  List<_ChartPoint> _downsampleCurve(
    List<_ChartPoint> source, {
    required int maxPoints,
  }) {
    if (source.length <= maxPoints) {
      return source;
    }

    final step = source.length / maxPoints;
    final sampled = <_ChartPoint>[];
    for (int i = 0; i < maxPoints; i++) {
      final index = min((i * step).round(), source.length - 1);
      sampled.add(source[index]);
    }
    return sampled;
  }

  bool _canGoNext() {
    if (_isRunning || _isInitializingSensor) {
      return false;
    }
    final currentId = _tests[_currentTestIndex].id;
    if (!_resultsByTestId.containsKey(currentId)) {
      return false;
    }
    return _currentTestIndex < _tests.length - 1;
  }

  void _goToNextTest() {
    if (!_canGoNext()) {
      return;
    }
    _postCheckTransitionToken++;
    final token = _postCheckTransitionToken;
    _autoAdvanceTimer?.cancel();
    final fromSpec = _tests[_currentTestIndex];
    final nextIndex = _currentTestIndex + 1;
    unawaited(() async {
      await _disableSensorForSpec(fromSpec);
      await _showCooldownAndMoveTo(nextIndex, token: token);
    }());
  }

  void _retryCurrentTest() {
    if (_isRunning) {
      return;
    }
    _postCheckTransitionToken++;
    _autoAdvanceTimer?.cancel();
    _hasDisabledSensorsAfterCompletion = false;
    final currentId = _tests[_currentTestIndex].id;
    setState(() {
      _isInitializingSensor = false;
      _resultsByTestId.remove(currentId);
      _liveHint = '';
      _liveCurve = const [];
    });
    _autoStartCurrentTestIfPossible();
  }

  void _retryTestById(String testId) {
    if (_isRunning) {
      return;
    }
    _postCheckTransitionToken++;
    _autoAdvanceTimer?.cancel();
    _hasDisabledSensorsAfterCompletion = false;
    final index = _tests.indexWhere((test) => test.id == testId);
    if (index < 0) {
      return;
    }
    setState(() {
      _isInitializingSensor = false;
      _resultsByTestId.remove(testId);
      _currentTestIndex = index;
      _liveHint = '';
      _liveCurve = const [];
    });
    _autoStartCurrentTestIfPossible();
  }

  void _resetAllTests() {
    if (_isRunning) {
      return;
    }
    _postCheckTransitionToken++;
    _autoAdvanceTimer?.cancel();
    _hasDisabledSensorsAfterCompletion = false;
    setState(() {
      _isInitializingSensor = false;
      _resultsByTestId.clear();
      _currentTestIndex = 0;
      _liveHint = '';
      _liveCurve = const [];
    });
  }

  void _restoreSavedConfigurations() {
    for (final entry in _savedConfigurations.entries) {
      final original = entry.value;
      if (original == null) {
        continue;
      }
      try {
        widget.sensorConfigProvider.addSensorConfiguration(
          entry.key,
          original,
          markPending: false,
        );
        entry.key.setConfiguration(original);
      } catch (_) {
        // Ignore restoration failures during widget teardown.
      }
    }
  }

  Future<void> _disableSensorsAfterCompletion() async {
    if (_hasDisabledSensorsAfterCompletion) {
      return;
    }
    _postCheckTransitionToken++;
    _hasDisabledSensorsAfterCompletion = true;
    _autoAdvanceTimer?.cancel();
    if (mounted && _isInitializingSensor) {
      setState(() {
        _isInitializingSensor = false;
      });
    }

    try {
      await widget.sensorConfigProvider.turnOffAllSensors();
      _savedConfigurations.clear();
      return;
    } catch (_) {
      // Fallback: explicitly set off values for touched configurations.
    }

    for (final config in _savedConfigurations.keys) {
      final offValue = config.offValue;
      if (offValue == null) {
        continue;
      }
      try {
        widget.sensorConfigProvider.addSensorConfiguration(
          config,
          offValue,
          markPending: false,
        );
        config.setConfiguration(offValue);
      } catch (_) {
        // Keep going with remaining configs.
      }
    }
    _savedConfigurations.clear();
  }

  Future<void> _setLedColor({
    required int r,
    required int g,
    required int b,
  }) async {
    if (!widget.wearable.hasCapability<RgbLed>()) {
      return;
    }

    try {
      if (widget.wearable.hasCapability<StatusLed>()) {
        await widget.wearable.requireCapability<StatusLed>().showStatus(false);
      }
      final dimmedR = (r * _ledBrightnessFactor).round().clamp(0, 255);
      final dimmedG = (g * _ledBrightnessFactor).round().clamp(0, 255);
      final dimmedB = (b * _ledBrightnessFactor).round().clamp(0, 255);
      await widget.wearable.requireCapability<RgbLed>().writeLedColor(
            r: dimmedR,
            g: dimmedG,
            b: dimmedB,
          );
    } catch (_) {
      // LED feedback should not interrupt test execution.
    }
  }

  Future<void> _resetLedColor() async {
    try {
      if (widget.wearable.hasCapability<StatusLed>()) {
        await widget.wearable.requireCapability<StatusLed>().showStatus(true);
        return;
      }
      if (widget.wearable.hasCapability<RgbLed>()) {
        await widget.wearable.requireCapability<RgbLed>().writeLedColor(
              r: 0,
              g: 0,
              b: 0,
            );
      }
    } catch (_) {
      // LED reset is best-effort and should not interrupt test execution.
    }
  }

  void _autoStartCurrentTestIfPossible() {
    if (!mounted || _isRunning || _isInitializingSensor) {
      return;
    }

    final provider = _wearablesProvider;
    if (provider == null) {
      return;
    }

    final connected = provider.wearables.any(
      (wearable) => wearable.deviceId == widget.wearable.deviceId,
    );
    if (!connected) {
      return;
    }

    final currentTestId = _tests[_currentTestIndex].id;
    if (_resultsByTestId.containsKey(currentTestId)) {
      return;
    }

    final sensor = _sensorByTestId[currentTestId];
    if (sensor == null) {
      return;
    }

    unawaited(_startCurrentTest());
  }
}

class _TestSpec {
  final String id;
  final String title;
  final String description;
  final Duration timeout;
  final int targetFrequencyHz;

  const _TestSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.timeout,
    required this.targetFrequencyHz,
  });
}

class _TestResult {
  final bool passed;
  final String message;
  final List<_ChartPoint> curve;

  const _TestResult({
    required this.passed,
    required this.message,
    required this.curve,
  });
}

class _SensorSample {
  final double timeSeconds;
  final List<double> values;

  const _SensorSample({
    required this.timeSeconds,
    required this.values,
  });
}

class _ChartPoint {
  final double x;
  final double y;

  const _ChartPoint(this.x, this.y);
}

abstract class _TestAnalyzer {
  bool get hasPassed;
  String get liveStatus;
  String get successMessage;

  void addSample(_SensorSample sample);
  double primaryValue(_SensorSample sample);
  String failureMessage({required bool timedOut});
}

class _MotionAnalyzer implements _TestAnalyzer {
  final String unitLabel;
  final String movementLabel;
  final int minimumEvents;
  final double deltaThreshold;
  final double minimumStdDev;
  final int minimumSamples;
  final double? highThreshold;
  final double? lowThreshold;

  final List<double> _magnitudes = [];

  int _events = 0;
  double? _previousMagnitude;
  double _lastEventTime = -1000;
  bool _peakStateHigh = false;
  bool _passed = false;
  double _stdDev = 0;

  _MotionAnalyzer({
    required this.unitLabel,
    required this.movementLabel,
    required this.minimumEvents,
    required this.deltaThreshold,
    required this.minimumStdDev,
    required this.minimumSamples,
    required this.highThreshold,
    required this.lowThreshold,
  });

  @override
  bool get hasPassed => _passed;

  @override
  String get liveStatus =>
      'Detected $_events of $minimumEvents required $movementLabel events. SD ${_stdDev.toStringAsFixed(1)} $unitLabel.';

  @override
  String get successMessage =>
      'Motion detected successfully ($_events events, SD ${_stdDev.toStringAsFixed(1)} $unitLabel).';

  @override
  void addSample(_SensorSample sample) {
    final magnitude = _vectorMagnitude(sample.values);
    _magnitudes.add(magnitude);

    if (highThreshold != null && lowThreshold != null) {
      if (!_peakStateHigh &&
          magnitude >= highThreshold! &&
          sample.timeSeconds - _lastEventTime >= 0.25) {
        _events += 1;
        _peakStateHigh = true;
        _lastEventTime = sample.timeSeconds;
      }
      if (_peakStateHigh && magnitude <= lowThreshold!) {
        _peakStateHigh = false;
      }
    } else {
      if (_previousMagnitude != null) {
        final delta = (magnitude - _previousMagnitude!).abs();
        if (delta >= deltaThreshold &&
            sample.timeSeconds - _lastEventTime >= 0.25) {
          _events += 1;
          _lastEventTime = sample.timeSeconds;
        }
      }
      _previousMagnitude = magnitude;
    }

    _stdDev = _stdDevOf(_magnitudes);
    _passed = _events >= minimumEvents &&
        _magnitudes.length >= minimumSamples &&
        _stdDev >= minimumStdDev;
  }

  @override
  double primaryValue(_SensorSample sample) {
    return _vectorMagnitude(sample.values);
  }

  @override
  String failureMessage({required bool timedOut}) {
    if (!timedOut) {
      return 'Motion quality check failed.';
    }
    return 'Not enough movement detected. Please repeat with stronger motion and at least $minimumEvents clear events.';
  }
}

class _BarometerAnalyzer implements _TestAnalyzer {
  final String unitLabel;
  final List<double> _values = [];
  final List<double> _times = [];

  static const double _minimumAbsolutePressurePa = 100000.0; // 100 kPa

  double _baselinePa = 0;
  double _baselineStdPa = 0;
  double _maxRisePa = 0;
  double _requiredRisePa = 0;
  double _maxAbsolutePressurePa = 0;
  double _sustainedStart = -1;
  bool _sustainedRise = false;
  bool _passed = false;

  _BarometerAnalyzer({
    required this.unitLabel,
  });

  double _toPascal(double value) {
    final unit = unitLabel.toLowerCase();
    if (unit.contains('kpa')) {
      return value * 1000.0;
    }
    if (unit.contains('hpa') || unit.contains('mbar')) {
      return value * 100.0;
    }
    if (unit.contains('pa')) {
      return value;
    }
    return value;
  }

  @override
  bool get hasPassed => _passed;

  @override
  String get liveStatus {
    final absKPa = _maxAbsolutePressurePa / 1000.0;
    final riseKPa = _maxRisePa / 1000.0;
    return 'Abs ${_maxAbsolutePressurePa.toStringAsFixed(0)} Pa (${absKPa.toStringAsFixed(2)} kPa), min 100000 Pa. Rise ${_maxRisePa.toStringAsFixed(0)} Pa (${riseKPa.toStringAsFixed(2)} kPa).';
  }

  @override
  String get successMessage {
    return 'Pressure response detected (abs ${_maxAbsolutePressurePa.toStringAsFixed(0)} Pa, rise +${_maxRisePa.toStringAsFixed(0)} Pa).';
  }

  @override
  void addSample(_SensorSample sample) {
    final valuePa = _toPascal(sample.values.first);
    if (valuePa > _maxAbsolutePressurePa) {
      _maxAbsolutePressurePa = valuePa;
    }

    final timeSec = sample.timeSeconds;
    _values.add(valuePa);
    _times.add(timeSec);

    final baselineWindow = <double>[];
    for (int i = 0; i < _values.length; i++) {
      if (_times[i] <= 2.0 || baselineWindow.length < 20) {
        baselineWindow.add(_values[i]);
      }
    }
    if (baselineWindow.isNotEmpty) {
      _baselinePa = _meanOf(baselineWindow);
      _baselineStdPa = _stdDevOf(baselineWindow);
    }

    const floorRisePa = 600.0; // 0.6 kPa
    const strongRisePa = 1200.0; // 1.2 kPa
    _requiredRisePa = max(floorRisePa, _baselineStdPa * 8);

    final risePa = valuePa - _baselinePa;
    if (risePa > _maxRisePa) {
      _maxRisePa = risePa;
    }

    if (risePa >= _requiredRisePa) {
      if (_sustainedStart < 0) {
        _sustainedStart = timeSec;
      }
      if (timeSec - _sustainedStart >= 0.45) {
        _sustainedRise = true;
      }
    } else if (risePa < _requiredRisePa * 0.6) {
      _sustainedStart = -1;
    }

    _passed = _maxAbsolutePressurePa >= _minimumAbsolutePressurePa &&
        (_maxRisePa >= strongRisePa || _sustainedRise);
  }

  @override
  double primaryValue(_SensorSample sample) {
    return sample.values.first;
  }

  @override
  String failureMessage({required bool timedOut}) {
    if (_maxAbsolutePressurePa < _minimumAbsolutePressurePa) {
      return 'Absolute pressure too low (${_maxAbsolutePressurePa.toStringAsFixed(0)} Pa). Need at least 100000 Pa.';
    }
    if (!timedOut) {
      return 'Pressure response check failed.';
    }
    return 'No clear pressure rise detected. Blow steadily into the device for about one second and retry.';
  }
}

class _MagnetometerAnalyzer implements _TestAnalyzer {
  final String unitLabel;
  final List<List<double>> _axisValues = [];

  static const int _minimumSamples = 40;
  static const int _requiredEvents = 3;
  static const double _minimumSpanUt = 18.0;
  static const double _minimumStdUt = 4.0;
  static const double _minimumDeltaEventUt = 6.0;

  int _sampleCount = 0;
  int _events = 0;
  double _strongestSpanUt = 0;
  double _strongestStdUt = 0;
  double _lastAxisUt = 0;
  double _lastEventTimeSec = -1000;
  bool _hasLastAxis = false;
  bool _passed = false;

  _MagnetometerAnalyzer({
    required this.unitLabel,
  });

  @override
  bool get hasPassed => _passed;

  @override
  String get liveStatus {
    return 'Move near metal/magnet. Events $_events/$_requiredEvents, span ${_strongestSpanUt.toStringAsFixed(1)} uT, SD ${_strongestStdUt.toStringAsFixed(1)} uT.';
  }

  @override
  String get successMessage {
    return 'Magnetometer response detected ($_events events, span ${_strongestSpanUt.toStringAsFixed(1)} uT).';
  }

  double _toMicroTesla(double value) {
    final unit = unitLabel.toLowerCase();
    if (unit.contains('mt')) {
      return value * 1000.0;
    }
    if (unit.contains('nt')) {
      return value / 1000.0;
    }
    return value;
  }

  @override
  void addSample(_SensorSample sample) {
    if (sample.values.isEmpty) {
      return;
    }

    final valuesUt = sample.values.map(_toMicroTesla).toList(growable: false);
    while (_axisValues.length < valuesUt.length) {
      _axisValues.add([]);
    }
    for (int i = 0; i < valuesUt.length; i++) {
      _axisValues[i].add(valuesUt[i]);
    }

    _sampleCount += 1;

    final dominantIndex = _indexOfLargestAbsolute(valuesUt);
    final dominantAxisUt = valuesUt[dominantIndex];
    if (_hasLastAxis) {
      final delta = (dominantAxisUt - _lastAxisUt).abs();
      if (delta >= _minimumDeltaEventUt &&
          sample.timeSeconds - _lastEventTimeSec >= 0.35) {
        _events += 1;
        _lastEventTimeSec = sample.timeSeconds;
      }
    }
    _lastAxisUt = dominantAxisUt;
    _hasLastAxis = true;

    double bestSpan = 0;
    double bestStd = 0;
    for (final axis in _axisValues) {
      if (axis.length < 2) {
        continue;
      }
      final minValue = axis.reduce(min);
      final maxValue = axis.reduce(max);
      final span = maxValue - minValue;
      if (span > bestSpan) {
        bestSpan = span;
      }
      final std = _stdDevOf(axis);
      if (std > bestStd) {
        bestStd = std;
      }
    }

    _strongestSpanUt = bestSpan;
    _strongestStdUt = bestStd;
    _passed = _sampleCount >= _minimumSamples &&
        _events >= _requiredEvents &&
        _strongestSpanUt >= _minimumSpanUt &&
        _strongestStdUt >= _minimumStdUt;
  }

  int _indexOfLargestAbsolute(List<double> values) {
    int bestIndex = 0;
    double bestValue = -1;
    for (int i = 0; i < values.length; i++) {
      final absValue = values[i].abs();
      if (absValue > bestValue) {
        bestValue = absValue;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  @override
  double primaryValue(_SensorSample sample) {
    if (sample.values.isEmpty) {
      return 0;
    }
    return _toMicroTesla(sample.values.first);
  }

  @override
  String failureMessage({required bool timedOut}) {
    if (!timedOut) {
      return 'Magnetometer quality check failed.';
    }
    return 'Magnetometer response too weak. Move near a small magnet or metal object and rotate the device.';
  }
}

class _TemperatureAnalyzer implements _TestAnalyzer {
  final String unitLabel;
  final List<double> _values = [];
  static const double _minimumFingerSurfaceTemp = 30.0;
  static const double _maximumExpectedTemp = 40.0;

  bool _passed = false;
  double _mean = 0;
  double _minimum = 0;
  double _maximum = 0;

  _TemperatureAnalyzer({
    required this.unitLabel,
  });

  @override
  bool get hasPassed => _passed;

  @override
  String get liveStatus {
    final current = _values.isNotEmpty ? _values.last : double.nan;
    if (current.isNaN) {
      return 'Waiting for temperature samples...';
    }
    return 'Current ${current.toStringAsFixed(1)} $unitLabel. Range ${_minimum.toStringAsFixed(1)} to ${_maximum.toStringAsFixed(1)} $unitLabel. Finger-contact range is ${_minimumFingerSurfaceTemp.toStringAsFixed(0)} to ${_maximumExpectedTemp.toStringAsFixed(0)} $unitLabel.';
  }

  @override
  String get successMessage =>
      'Temperature sensor active (${_mean.toStringAsFixed(1)} $unitLabel, span ${(_maximum - _minimum).toStringAsFixed(2)} $unitLabel).';

  @override
  void addSample(_SensorSample sample) {
    final value = sample.values.first;
    _values.add(value);

    _mean = _meanOf(_values);
    _minimum = _values.reduce(min);
    _maximum = _values.reduce(max);
    final span = _maximum - _minimum;

    final inRange =
        _mean >= _minimumFingerSurfaceTemp && _mean <= _maximumExpectedTemp;
    final notStatic = span >= 0.12;
    _passed = _values.length >= 12 && inRange && notStatic;
  }

  @override
  double primaryValue(_SensorSample sample) {
    return sample.values.first;
  }

  @override
  String failureMessage({required bool timedOut}) {
    if (_values.isEmpty) {
      return 'No temperature values received.';
    }

    if (_mean < _minimumFingerSurfaceTemp || _mean > _maximumExpectedTemp) {
      return 'Temperature average is ${_mean.toStringAsFixed(1)} $unitLabel. Expected finger-contact range is ${_minimumFingerSurfaceTemp.toStringAsFixed(0)} to ${_maximumExpectedTemp.toStringAsFixed(0)} $unitLabel.';
    }

    final span = _maximum - _minimum;
    if (span < 0.12) {
      return 'Temperature data appears static. Move the device between air and skin briefly, then retry.';
    }

    return timedOut
        ? 'Temperature check timed out.'
        : 'Temperature quality check failed.';
  }
}

class _PpgAnalyzer implements _TestAnalyzer {
  static const double _minimumBpm = 35.0;
  static const double _maximumBpm = 180.0;
  static const double _minimumWindowSeconds = 8.0;
  static const int _minimumSampleCount = 80;

  final List<double> _times = [];
  final List<List<double>> _axisValues = [];

  bool _passed = false;
  double? _detectedBpm;
  double? _peakBpm;
  double? _autocorrBpm;
  double _autocorrScore = 0;
  int _detectedPeaks = 0;

  @override
  bool get hasPassed => _passed;

  @override
  String get liveStatus {
    if (_detectedBpm != null) {
      return 'Pulse candidate ${_detectedBpm!.toStringAsFixed(0)} BPM (peaks $_detectedPeaks, corr ${_autocorrScore.toStringAsFixed(2)}).';
    }
    if (_autocorrBpm != null) {
      return 'Pulse candidate ${_autocorrBpm!.toStringAsFixed(0)} BPM. Keep finger contact stable.';
    }
    return 'Looking for a pulse pattern. Keep finger contact stable.';
  }

  @override
  String get successMessage =>
      'Pulse detected (${_detectedBpm?.toStringAsFixed(0) ?? '--'} BPM).';

  @override
  void addSample(_SensorSample sample) {
    _times.add(sample.timeSeconds);
    while (_axisValues.length < sample.values.length) {
      _axisValues.add([]);
    }
    for (int i = 0; i < sample.values.length; i++) {
      _axisValues[i].add(sample.values[i]);
    }

    if (_times.length < _minimumSampleCount) {
      return;
    }
    final windowSeconds = _times.last - _times.first;
    if (windowSeconds < _minimumWindowSeconds) {
      return;
    }

    final axisIndex = _axisWithHighestStdDev();
    final source = _axisValues[axisIndex];

    final mean = _meanOf(source);
    final centered =
        source.map((value) => value - mean).toList(growable: false);
    final smoothed = _movingAverage(centered, radius: 2);
    final std = _stdDevOf(smoothed);
    if (std <= 0) {
      return;
    }

    final threshold = std * 0.30;
    final peaks = <double>[];
    final minIntervalSec = 60.0 / _maximumBpm;

    for (int i = 1; i < smoothed.length - 1; i++) {
      final prev = smoothed[i - 1];
      final curr = smoothed[i];
      final next = smoothed[i + 1];
      if (curr <= prev || curr <= next || curr < threshold) {
        continue;
      }
      final t = _times[i];
      if (peaks.isNotEmpty) {
        final dt = t - peaks.last;
        if (dt < minIntervalSec) {
          continue;
        }
      }
      peaks.add(t);
    }

    _detectedPeaks = peaks.length;
    _peakBpm = _estimateBpmFromPeaks(peaks);
    final normalized =
        smoothed.map((value) => value / std).toList(growable: false);
    _autocorrBpm = _estimateBpmFromAutocorrelation(
      normalized,
      windowSeconds: windowSeconds,
    );

    final peakValid = _peakBpm != null;
    final corrValid = _autocorrBpm != null && _autocorrScore >= 0.20;

    double? candidateBpm;
    if (peakValid && corrValid && (_peakBpm! - _autocorrBpm!).abs() <= 12.0) {
      candidateBpm = (_peakBpm! + _autocorrBpm!) / 2.0;
    } else if (corrValid && _autocorrScore >= 0.28) {
      candidateBpm = _autocorrBpm;
    } else if (peakValid && _detectedPeaks >= 4) {
      candidateBpm = _peakBpm;
    }

    if (candidateBpm == null) {
      return;
    }

    final bpm = candidateBpm;
    if (bpm < _minimumBpm || bpm > _maximumBpm) {
      return;
    }
    _detectedBpm = bpm;
    _passed = true;
  }

  double? _estimateBpmFromPeaks(List<double> peaks) {
    if (peaks.length < 4) {
      return null;
    }
    final minIntervalSec = 60.0 / _maximumBpm;
    final maxIntervalSec = 60.0 / _minimumBpm;
    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      final dt = peaks[i] - peaks[i - 1];
      if (dt >= minIntervalSec && dt <= maxIntervalSec) {
        intervals.add(dt);
      }
    }
    if (intervals.length < 3) {
      return null;
    }
    final avgInterval = _meanOf(intervals);
    return avgInterval <= 0 ? null : 60.0 / avgInterval;
  }

  double? _estimateBpmFromAutocorrelation(
    List<double> normalized, {
    required double windowSeconds,
  }) {
    _autocorrScore = 0;
    if (normalized.length < 40 || windowSeconds <= 0) {
      return null;
    }

    final avgDt = windowSeconds / max(1, normalized.length - 1);
    if (avgDt <= 0) {
      return null;
    }

    final minLag = max(2, (60.0 / _maximumBpm / avgDt).round());
    final maxLag =
        min(normalized.length - 3, (60.0 / _minimumBpm / avgDt).round());
    if (maxLag <= minLag) {
      return null;
    }

    var bestLag = -1;
    var bestScore = -1.0;

    for (int lag = minLag; lag <= maxLag; lag++) {
      var cross = 0.0;
      var energyA = 0.0;
      var energyB = 0.0;
      for (int i = lag; i < normalized.length; i++) {
        final a = normalized[i];
        final b = normalized[i - lag];
        cross += a * b;
        energyA += a * a;
        energyB += b * b;
      }

      final denom = sqrt(energyA * energyB);
      if (denom <= 1e-9) {
        continue;
      }

      final score = cross / denom;
      if (score > bestScore) {
        bestScore = score;
        bestLag = lag;
      }
    }

    if (bestLag < 0) {
      return null;
    }

    _autocorrScore = bestScore;
    final periodSeconds = bestLag * avgDt;
    if (periodSeconds <= 0) {
      return null;
    }
    return 60.0 / periodSeconds;
  }

  int _axisWithHighestStdDev() {
    int bestIndex = 0;
    double bestStdDev = -1;
    for (int i = 0; i < _axisValues.length; i++) {
      final axis = _axisValues[i];
      if (axis.isEmpty) {
        continue;
      }
      final std = _stdDevOf(axis);
      if (std > bestStdDev) {
        bestStdDev = std;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  @override
  double primaryValue(_SensorSample sample) {
    if (sample.values.isEmpty) {
      return 0;
    }
    return sample.values.first;
  }

  @override
  String failureMessage({required bool timedOut}) {
    if (!timedOut) {
      return 'PPG quality check failed.';
    }
    return 'No reliable pulse pattern detected. Place PPG on a finger and keep still for around 10 seconds, then retry.';
  }
}

class _OverviewCard extends StatelessWidget {
  final Wearable wearable;
  final int completed;
  final int total;
  final int passed;
  final bool connected;
  final List<_TestSpec> tests;
  final Map<String, _TestResult> resultsByTestId;
  final _TestSpec currentSpec;
  final bool running;
  final bool initializing;
  final bool currentHasSensor;
  final _TestResult? currentResult;
  final VoidCallback? onStartPressed;
  final VoidCallback? onNextPressed;
  final VoidCallback? onRetryPressed;
  final VoidCallback? onRunAllAgainPressed;

  const _OverviewCard({
    required this.wearable,
    required this.completed,
    required this.total,
    required this.passed,
    required this.connected,
    required this.tests,
    required this.resultsByTestId,
    required this.currentSpec,
    required this.running,
    required this.initializing,
    required this.currentHasSensor,
    required this.currentResult,
    required this.onStartPressed,
    required this.onNextPressed,
    required this.onRetryPressed,
    required this.onRunAllAgainPressed,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          formatWearableDisplayName(wearable.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (wearable.hasCapability<StereoDevice>()) ...[
                        const SizedBox(width: 8),
                        StereoPositionBadge(
                          device: wearable.requireCapability<StereoDevice>(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: connected ? 'Connected' : 'Disconnected',
                  passed: connected,
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
            ),
            const SizedBox(height: 10),
            Text(
              '$completed of $total tests completed. $passed passed.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 0.6,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 10),
            Text(
              'Quick Summary',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tests.map((test) {
                final result = resultsByTestId[test.id];
                final isCurrent = currentSpec.id == test.id;
                final isActive = isCurrent && (running || initializing);

                final bool isPass = result?.passed == true;
                final bool isFail = result != null && !result.passed;
                final IconData icon = isPass
                    ? Icons.check_circle_rounded
                    : isFail
                        ? Icons.cancel_rounded
                        : isActive
                            ? Icons.hourglass_top_rounded
                            : Icons.radio_button_unchecked_rounded;
                final Color color = isPass
                    ? const Color(0xFF2F8F5B)
                    : isFail
                        ? theme.colorScheme.error
                        : isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: color.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        _summaryLabelFor(test),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 0.6,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 10),
            if (onRunAllAgainPressed != null) ...[
              SizedBox(
                width: double.infinity,
                child: PlatformElevatedButton(
                  onPressed: initializing ? null : onRunAllAgainPressed,
                  child: PlatformText('Run All Tests Again'),
                ),
              ),
            ] else if (currentResult != null) ...[
              Row(
                children: [
                  Expanded(
                    child: PlatformElevatedButton(
                      onPressed:
                          !running && !initializing ? onRetryPressed : null,
                      color: const Color(0xFF8E8E93),
                      child: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                  if (onNextPressed != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: PlatformElevatedButton(
                        onPressed: initializing ? null : onNextPressed,
                        child: PlatformText('Next Test'),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: PlatformElevatedButton(
                  onPressed: !running && !initializing && currentHasSensor
                      ? onStartPressed
                      : null,
                  child: PlatformText(
                    running ? 'Running...' : 'Start Test',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _summaryLabelFor(_TestSpec test) {
    return switch (test.id) {
      'accelerometer' => 'Accel',
      'gyroscope' => 'Gyro',
      'magnetometer' => 'Mag',
      'barometer' => 'Baro',
      'temperature' => 'Temp',
      'ppg' => 'PPG',
      _ => test.title,
    };
  }
}

class _CurrentTestCard extends StatelessWidget {
  final _TestSpec spec;
  final Sensor? sensor;
  final bool running;
  final bool initializing;
  final String liveHint;
  final List<_ChartPoint> liveCurve;
  final _TestResult? result;

  const _CurrentTestCard({
    required this.spec,
    required this.sensor,
    required this.running,
    required this.initializing,
    required this.liveHint,
    required this.liveCurve,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResult = result != null;
    final hasSensor = sensor != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    spec.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (hasResult)
                  _StatusChip(
                    label: result!.passed ? 'Passed' : 'Failed',
                    passed: result!.passed,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              spec.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            if (!hasSensor)
              Text(
                'Sensor not found for this test on the selected device.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (initializing)
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: PlatformCircularProgressIndicator(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Initializing ${spec.title}... cooling down firmware for 1 second.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            else if (running)
              Text(
                liveHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (hasResult)
              Text(
                result!.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: result!.passed
                      ? const Color(0xFF2F8F5B)
                      : theme.colorScheme.error,
                ),
              ),
            if (running ||
                liveCurve.isNotEmpty ||
                (hasResult && result!.curve.isNotEmpty)) ...[
              const SizedBox(height: 8),
              _SignalChart(
                points: running ? liveCurve : (result?.curve ?? const []),
                height: 92,
                color: hasResult && !(result?.passed ?? true)
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  final List<_TestSpec> tests;
  final Map<String, _TestResult> resultsByTestId;
  final bool running;
  final void Function(String testId)? onRetryTest;

  const _ResultsCard({
    required this.tests,
    required this.resultsByTestId,
    required this.running,
    required this.onRetryTest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Test Report',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(tests.length, (index) {
              final test = tests[index];
              final result = resultsByTestId[test.id];
              final hasResult = result != null;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                test.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                !hasResult ? 'Pending' : result.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: hasResult && !result.passed
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: hasResult
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasResult && result.curve.isNotEmpty)
                          SizedBox(
                            width: 110,
                            child: _SignalChart(
                              points: result.curve,
                              height: 44,
                              color: result.passed
                                  ? const Color(0xFF2F8F5B)
                                  : theme.colorScheme.error,
                            ),
                          )
                        else
                          const SizedBox(width: 110),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _StatusChip(
                              label: !hasResult
                                  ? 'Pending'
                                  : result.passed
                                      ? 'Pass'
                                      : 'Fail',
                              passed: hasResult && result.passed,
                            ),
                            if (hasResult) ...[
                              const SizedBox(height: 4),
                              PlatformTextButton(
                                onPressed: running
                                    ? null
                                    : () => onRetryTest?.call(test.id),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index < tests.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.6,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.55,
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool passed;

  const _StatusChip({
    required this.label,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        passed ? const Color(0xFF2F8F5B) : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SignalChart extends StatelessWidget {
  final List<_ChartPoint> points;
  final double height;
  final Color color;

  const _SignalChart({
    required this.points,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No signal yet',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final yValues = points.map((point) => point.y).toList(growable: false);
    var minY = yValues.reduce(min);
    var maxY = yValues.reduce(max);
    if ((maxY - minY).abs() < 1e-9) {
      minY -= 1;
      maxY += 1;
    }

    final minX = points.first.x;
    final maxX = points.last.x <= minX ? minX + 1 : points.last.x;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: points
                  .map((point) => FlSpot(point.x, point.y))
                  .toList(growable: false),
              isCurved: true,
              color: color,
              barWidth: 1.8,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 0),
      ),
    );
  }
}

double _vectorMagnitude(List<double> values) {
  var sum = 0.0;
  for (final value in values) {
    sum += value * value;
  }
  return sqrt(sum);
}

double _meanOf(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  var sum = 0.0;
  for (final value in values) {
    sum += value;
  }
  return sum / values.length;
}

double _stdDevOf(List<double> values) {
  if (values.length < 2) {
    return 0;
  }
  final mean = _meanOf(values);
  var varianceSum = 0.0;
  for (final value in values) {
    final diff = value - mean;
    varianceSum += diff * diff;
  }
  return sqrt(varianceSum / values.length);
}

List<double> _movingAverage(
  List<double> input, {
  required int radius,
}) {
  if (input.isEmpty) {
    return const [];
  }
  final output = <double>[];
  for (int i = 0; i < input.length; i++) {
    final start = max(0, i - radius);
    final end = min(input.length - 1, i + radius);
    var sum = 0.0;
    var count = 0;
    for (int j = start; j <= end; j++) {
      sum += input[j];
      count += 1;
    }
    output.add(sum / count);
  }
  return output;
}
