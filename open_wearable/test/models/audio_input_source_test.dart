import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/audio_input_source.dart';

void main() {
  group('AudioInputSource', () {
    test('classifies common microphone labels for display', () {
      expect(
        classifyAudioInputSourceLabel('OpenEarable Ring Microphone'),
        AudioInputSourceKind.wearable,
      );
      expect(
        classifyAudioInputSourceLabel('Bluetooth Headset'),
        AudioInputSourceKind.bluetooth,
      );
      expect(
        classifyAudioInputSourceLabel('Built-in Phone Microphone'),
        AudioInputSourceKind.builtIn,
      );
      expect(
        classifyAudioInputSourceLabel('USB Audio Interface'),
        AudioInputSourceKind.external,
      );
      expect(
        classifyAudioInputSourceLabel('Studio Microphone'),
        AudioInputSourceKind.unknown,
      );
    });

    test('represents the system default as an app-owned synthetic source', () {
      expect(AudioInputSource.systemDefault.isSystemDefault, isTrue);
      expect(
        AudioInputSource.systemDefault.kind,
        AudioInputSourceKind.systemDefault,
      );
    });
  });
}
