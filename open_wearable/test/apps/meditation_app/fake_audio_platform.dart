// A stand-in for the native audioplayers implementation, shared by the
// meditation tests that need a real AudioPlayer to run.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the native audioplayers implementation.
///
/// The plugin waits for a `prepared` event before it will resume, and the
/// narration player waits for `complete` before moving on, so both have to be
/// pushed back through the event channel the way the platform would.
class FakeAudioPlatform {
  static const _playbackDuration = Duration(milliseconds: 60);
  static const _methodChannel = MethodChannel('xyz.luan/audioplayers');
  static const _globalChannel = MethodChannel('xyz.luan/audioplayers.global');
  static const _pathProvider =
      MethodChannel('plugins.flutter.io/path_provider');
  static const _codec = StandardMethodCodec();

  final _messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final Set<String> _players = {};
  final Set<String> _stopped = {};
  bool _mockAssets = true;

  /// Makes asset loading fail, as a file the platform cannot decode does.
  bool failAssetLoading = false;

  /// [mockAssets] also intercepts asset loading, which the background-music
  /// player needs. Leave it off in files whose widget tests load real assets.
  void install({bool mockAssets = true}) {
    _mockAssets = mockAssets;
    _messenger.setMockMethodCallHandler(_methodChannel, _handle);
    _messenger.setMockMethodCallHandler(_globalChannel, (_) async => null);
    _messenger.setMockMethodCallHandler(
      _pathProvider,
      (_) async => Directory.systemTemp.path,
    );
    if (!mockAssets) return;
    // The background-music asset is 200+ MB of WAV on disk; the player never
    // decodes it here, so a stub of a few bytes is enough.
    _messenger.setMockMessageHandler(
      'flutter/assets',
      (_) async => failAssetLoading
          ? null
          : ByteData.view(Uint8List.fromList(const [0, 0, 0, 0]).buffer),
    );
  }

  void uninstall() {
    _messenger.setMockMethodCallHandler(_methodChannel, null);
    _messenger.setMockMethodCallHandler(_globalChannel, null);
    _messenger.setMockMethodCallHandler(_pathProvider, null);
    if (_mockAssets) _messenger.setMockMessageHandler('flutter/assets', null);
    for (final playerId in _players) {
      _messenger.setMockMethodCallHandler(
        MethodChannel(_eventChannelName(playerId)),
        null,
      );
    }
    _players.clear();
  }

  static String _eventChannelName(String playerId) =>
      'xyz.luan/audioplayers/events/$playerId';

  Future<Object?> _handle(MethodCall call) async {
    final arguments = call.arguments as Map<Object?, Object?>?;
    final playerId = arguments?['playerId'] as String?;

    switch (call.method) {
      case 'create':
        _players.add(playerId!);
        _messenger.setMockMethodCallHandler(
          MethodChannel(_eventChannelName(playerId)),
          (_) async => null,
        );
      case 'setSourceUrl':
      case 'setSourceBytes':
        _stopped.remove(playerId);
        _emit(playerId!, const {'event': 'audio.onPrepared', 'value': true});
      case 'resume':
        // Pausing suspends the pending completion; resuming re-arms it, the
        // way a real player continues where it left off.
        _stopped.remove(playerId);
        _resumeAndComplete(playerId!);
      case 'stop':
      case 'pause':
      case 'release':
        _stopped.add(playerId!);
      case 'dispose':
        _stopped.add(playerId!);
        _players.remove(playerId);
      case 'getCurrentPosition':
        return 0;
    }
    return null;
  }

  void _resumeAndComplete(String playerId) {
    Future<void>.delayed(_playbackDuration, () {
      if (_stopped.contains(playerId) || !_players.contains(playerId)) return;
      _emit(playerId, const {'event': 'audio.onComplete'});
    });
  }

  /// Delivered on a later turn so the plugin's stream subscription is in place.
  void _emit(String playerId, Map<String, Object?> event) {
    Future<void>.delayed(Duration.zero, () {
      if (!_players.contains(playerId)) return;
      _messenger.handlePlatformMessage(
        _eventChannelName(playerId),
        _codec.encodeSuccessEnvelope(event),
        (_) {},
      );
    });
  }
}
