import 'dart:async';

class SimpleEventBus {
  final _controller = StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _controller.stream;

  void sendEvent(dynamic event) {
    if (!_controller.isClosed) {
      _controller.sink.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }

  static final SimpleEventBus _instance = SimpleEventBus._internal();

  factory SimpleEventBus() {
    return _instance;
  }

  SimpleEventBus._internal();
}
