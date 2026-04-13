import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'stereo_pair_option_selector.dart';

/// Selects which microphone is streamed over LE Audio for a wearable.
class MicrophoneSelectionWidget extends StatelessWidget {
  /// The wearable whose microphone routing should be configured.
  final Wearable device;

  /// Defines whether the selection can target the paired device.
  final StereoPairApplyScope applyScope;

  const MicrophoneSelectionWidget({
    super.key,
    required this.device,
    this.applyScope = StereoPairApplyScope.userSelectable,
  });

  @override
  Widget build(BuildContext context) {
    return StereoPairOptionSelector<Microphone, MicrophoneManager>(
      device: device,
      applyScope: applyScope,
      title: 'LE Audio Microphone Stream',
      description: 'Choose which microphone is streamed via LE Audio.',
      supportsSetting: (wearable) =>
          wearable.hasCapability<MicrophoneManager>(),
      managerFor: (wearable) => wearable.requireCapability<MicrophoneManager>(),
      readSelection: (manager) => manager.getMicrophone(),
      applySelection: (manager, microphone) async {
        manager.setMicrophone(microphone);
      },
      optionsFor: (manager) => manager.availableMicrophones,
      supportsOption: (manager, microphone) => manager.availableMicrophones.any(
        (candidate) => _microphonesEqualByKey(candidate, microphone),
      ),
      equalsSelection: _microphonesEqualByKey,
      optionLabel: _labelForMicrophone,
      optionSubtitle: _subtitleForMicrophone,
      optionIcon: _iconForMicrophone,
      loadErrorText: (error) =>
          'Failed to read LE Audio stream source: ${_describeError(error)}',
      applyErrorText: (
        error, {
        required bool primaryApplied,
        required bool appliedToPair,
      }) {
        final detail = _describeError(error);
        if (primaryApplied && appliedToPair) {
          return 'Applied to this device, but failed on paired device: $detail';
        }
        return 'Failed to apply LE Audio stream source: $detail';
      },
    );
  }
}

/// Compares two microphone options using normalized keys.
bool _microphonesEqualByKey(Microphone? a, Microphone b) {
  if (a == null) {
    return false;
  }
  return _normalizedMicrophoneKey(a) == _normalizedMicrophoneKey(b);
}

/// Converts a microphone identifier into a user-facing label.
String _labelForMicrophone(Microphone microphone) {
  final normalized = _normalizedMicrophoneKey(microphone);
  if (normalized.contains('inner') || normalized.contains('internal')) {
    return 'Inner (In-Ear Sounds)';
  }
  if (normalized.contains('outer') || normalized.contains('external')) {
    return 'Outer (Ambient Sounds)';
  }
  return _toTitleCase(microphone.key);
}

/// Describes the effect of streaming a microphone source.
String _subtitleForMicrophone(Microphone microphone) {
  final normalized = _normalizedMicrophoneKey(microphone);
  if (normalized.contains('inner') || normalized.contains('internal')) {
    return 'Stream the inner mic over LE Audio';
  }
  if (normalized.contains('outer') || normalized.contains('external')) {
    return 'Stream the outer mic over LE Audio';
  }
  return 'Microphone source for LE Audio stream';
}

/// Chooses the icon that represents a microphone source.
IconData _iconForMicrophone(Microphone microphone) {
  final normalized = _normalizedMicrophoneKey(microphone);
  if (normalized.contains('inner') || normalized.contains('internal')) {
    return Icons.hearing_rounded;
  }
  if (normalized.contains('outer') || normalized.contains('external')) {
    return Icons.surround_sound_rounded;
  }
  return Icons.mic_rounded;
}

/// Normalizes a microphone key so different naming styles compare consistently.
String _normalizedMicrophoneKey(Microphone microphone) {
  return microphone.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Converts camel case and snake case strings into title case.
String _toTitleCase(String value) {
  final spaced = value
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim();

  if (spaced.isEmpty) {
    return value;
  }

  return spaced.split(RegExp(r'\s+')).map((word) {
    if (word.isEmpty) {
      return word;
    }
    if (word.length == 1) {
      return word.toUpperCase();
    }
    return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
  }).join(' ');
}

/// Trims transport-specific prefixes from surfaced errors.
String _describeError(Object error) {
  final text = error.toString().trim();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  if (text.startsWith('StateError: ')) {
    return text.substring('StateError: '.length);
  }
  return text;
}
