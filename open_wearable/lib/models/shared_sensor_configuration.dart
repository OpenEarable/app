import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';

typedef _Report = Map<SensorConfiguration, SensorConfigurationValue>;
final _reports = Expando<_SharedReports>();

/// One hardware subscription per manager, shared by the UI and connectors.
/// New listeners receive the latest report; the last cancellation releases BLE.
Stream<Map<SensorConfiguration, SensorConfigurationValue>>
    sharedSensorConfiguration(SensorConfigurationManager manager) =>
        (_reports[manager] ??= _SharedReports(manager)).stream;

class _SharedReports {
  _SharedReports(this.manager);
  final SensorConfigurationManager manager;
  final _listeners = <MultiStreamController<_Report>>{};
  StreamSubscription<_Report>? _source;
  Future<void>? _cancelling;
  bool _starting = false;
  _Report? _latest;

  late final stream = Stream<_Report>.multi(
    (listener) {
      _listeners.add(listener);
      if (_latest != null) listener.add(_latest!);
      listener.onCancel = () {
        _listeners.remove(listener);
        if (_listeners.isEmpty) {
          _latest = null;
          if (_source != null) {
            _cancelling = _source!.cancel();
            _source = null;
          }
        }
      };
      _start();
    },
    isBroadcast: true,
  );

  Future<void> _start() async {
    if (_source != null || _starting) return;
    _starting = true;
    try {
      // Finish cancellation before a new getter can replace the BLE listener.
      if (_cancelling != null) await _cancelling;
      if (_listeners.isEmpty) return;
      _source = manager.sensorConfigurationStream.listen(
        (report) {
          _latest = Map.unmodifiable(report);
          for (final listener in _listeners.toList()) {
            listener.addSync(_latest!);
          }
        },
        onError: (Object error, StackTrace stack) {
          for (final listener in _listeners.toList()) {
            listener.addErrorSync(error, stack);
          }
        },
        onDone: () {
          _source = null;
          _latest = null;
          final listeners = _listeners.toList();
          _listeners.clear();
          for (final listener in listeners) {
            listener.closeSync();
          }
        },
      );
    } finally {
      _starting = false;
    }
  }
}
