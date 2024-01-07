import 'dart:async';

/// This is a simple static event bus used to pass events 
/// between the Spotify and Tracker Blocs more easily.
class SimpleEventBus {
  final _controller = StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _controller.stream;

  /// Send any event on the stream
  /// 
  /// Args:
  ///   event (dynamic): The event to be sent
  void sendEvent(dynamic event) {
    if (!_controller.isClosed) {
      _controller.sink.add(event);
    }
  }

  /// Close the controller to avoid memory leaks.
  void dispose() {
    _controller.close();
  }

  static final SimpleEventBus _instance = SimpleEventBus._internal();

  factory SimpleEventBus() {
    return _instance;
  }

  // Create static instance
  SimpleEventBus._internal();
}
