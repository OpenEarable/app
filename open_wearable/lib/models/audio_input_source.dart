/// Describes an audio input that can be used for local audio recordings.
///
/// The app owns this model instead of exposing the recorder plugin's device
/// type through the UI. That keeps persisted selections and widgets isolated
/// from platform plugin implementation details.
class AudioInputSource {
  /// Stable identifier used by the platform recorder to select this source.
  final String id;

  /// Human-readable label surfaced by the platform.
  final String label;

  /// Coarse category used for icons and explanatory UI.
  final AudioInputSourceKind kind;

  /// Whether this option delegates source selection to the operating system.
  final bool isSystemDefault;

  const AudioInputSource({
    required this.id,
    required this.label,
    required this.kind,
    this.isSystemDefault = false,
  });

  /// The synthetic source that lets the OS pick its current default input.
  static const systemDefault = AudioInputSource(
    id: '__system_default_audio_input__',
    label: 'System Default',
    kind: AudioInputSourceKind.systemDefault,
    isSystemDefault: true,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioInputSource &&
        other.id == id &&
        other.label == label &&
        other.kind == kind &&
        other.isSystemDefault == isSystemDefault;
  }

  @override
  int get hashCode => Object.hash(id, label, kind, isSystemDefault);
}

/// Coarse audio input categories used to keep UI copy and icons consistent.
enum AudioInputSourceKind {
  systemDefault,
  builtIn,
  bluetooth,
  wearable,
  external,
  unknown,
}

/// Classifies a platform microphone label for display purposes.
AudioInputSourceKind classifyAudioInputSourceLabel(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('openearable') ||
      normalized.contains('open earable') ||
      normalized.contains('wearable')) {
    return AudioInputSourceKind.wearable;
  }
  if (normalized.contains('bluetooth') ||
      normalized.contains('ble') ||
      normalized.contains('headset') ||
      normalized.contains('airpods')) {
    return AudioInputSourceKind.bluetooth;
  }
  if (normalized.contains('built-in') ||
      normalized.contains('builtin') ||
      RegExp(r'\bphone\b').hasMatch(normalized) ||
      normalized.contains('internal')) {
    return AudioInputSourceKind.builtIn;
  }
  if (normalized.contains('usb') ||
      normalized.contains('external') ||
      normalized.contains('line in')) {
    return AudioInputSourceKind.external;
  }
  return AudioInputSourceKind.unknown;
}
