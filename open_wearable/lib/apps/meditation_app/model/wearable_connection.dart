import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Tracks whether the earbud this in-app was started for is still connected.
///
/// The in-app is pushed as its own route, so when the wearable drops the
/// screen underneath rebuilds but the session on top keeps running against a
/// device that is no longer there. Nothing in the meditation pipeline notices:
/// the sensor streams simply stop delivering.
///
/// The SDK reports a disconnect through a listener and offers neither a way to
/// remove one nor a way to read the current state, so this keeps the state
/// itself and ignores callbacks once disposed. Re-entering the in-app
/// therefore leaves an inert listener behind on the wearable; that is the
/// SDK's shape, not a leak this class can close.
class WearableConnection extends ChangeNotifier {
  bool _isConnected;
  bool _isDisposed = false;

  WearableConnection(Wearable? wearable) : _isConnected = wearable != null {
    wearable?.addDisconnectListener(_onDisconnected);
  }

  /// A connection that is always reported as present, for contexts with no
  /// wearable to watch.
  WearableConnection.alwaysConnected() : _isConnected = true;

  bool get isConnected => _isConnected;

  void _onDisconnected() {
    if (_isDisposed || !_isConnected) return;
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
