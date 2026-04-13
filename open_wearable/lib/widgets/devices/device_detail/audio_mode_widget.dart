import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'stereo_pair_option_selector.dart';

/// Selects the listening mode for a wearable using the shared stereo-pair selector.
class AudioModeWidget extends StatelessWidget {
  /// The wearable whose listening mode should be configured.
  final Wearable device;

  /// Defines whether the selection can target the paired device.
  final StereoPairApplyScope applyScope;

  const AudioModeWidget({
    super.key,
    required this.device,
    this.applyScope = StereoPairApplyScope.userSelectable,
  });

  @override
  Widget build(BuildContext context) {
    return StereoPairOptionSelector<AudioMode, AudioModeManager>(
      device: device,
      applyScope: applyScope,
      title: 'Listening Mode',
      description: 'Choose how much surrounding sound to let in.',
      supportsSetting: (wearable) => wearable.hasCapability<AudioModeManager>(),
      managerFor: (wearable) => wearable.requireCapability<AudioModeManager>(),
      readSelection: (manager) => manager.getAudioMode(),
      applySelection: (manager, mode) async {
        manager.setAudioMode(mode);
      },
      optionsFor: (manager) => manager.availableAudioModes,
      supportsOption: (manager, mode) => manager.availableAudioModes.any(
        (candidate) => _modesEqualByKey(candidate, mode),
      ),
      equalsSelection: _modesEqualByKey,
      optionLabel: _labelForMode,
      optionSubtitle: _subtitleForMode,
      optionIcon: _iconForMode,
      optionBadgeText: (mode) => _isNoiseCancellationMode(mode) ? 'BETA' : null,
      loadErrorText: (error) =>
          'Failed to load listening mode: ${_describeError(error)}',
      applyErrorText: (
        error, {
        required bool primaryApplied,
        required bool appliedToPair,
      }) {
        final detail = _describeError(error);
        if (primaryApplied && appliedToPair) {
          return 'Applied to this device, but failed on paired device: $detail';
        }
        return 'Failed to apply listening mode: $detail';
      },
      wideColumns: 3,
      wideLayoutMinWidth: 520,
    );
  }
}

/// Compares two audio modes using their normalized keys.
bool _modesEqualByKey(AudioMode? a, AudioMode b) {
  if (a == null) {
    return false;
  }
  return _normalizedModeKey(a) == _normalizedModeKey(b);
}

/// Converts an audio mode into a user-facing label.
String _labelForMode(AudioMode mode) {
  final normalized = _normalizedModeKey(mode);
  if (normalized.contains('noise') || normalized.contains('anc')) {
    return 'Noise Cancellation';
  }
  if (normalized.contains('transparen') ||
      normalized.contains('ambient') ||
      normalized.contains('passthrough')) {
    return 'Transparency';
  }
  if (normalized.contains('normal') ||
      normalized.contains('off') ||
      normalized.contains('default')) {
    return 'Standard';
  }
  return _toTitleCase(mode.key);
}

/// Describes the effect of an audio mode.
String _subtitleForMode(AudioMode mode) {
  final normalized = _normalizedModeKey(mode);
  if (normalized.contains('noise') || normalized.contains('anc')) {
    return 'Reduce background sound';
  }
  if (normalized.contains('transparen') ||
      normalized.contains('ambient') ||
      normalized.contains('passthrough')) {
    return 'Let surrounding sound in';
  }
  if (normalized.contains('normal') ||
      normalized.contains('off') ||
      normalized.contains('default')) {
    return 'No noise cancellation or transparency';
  }
  return 'Custom listening profile';
}

/// Returns whether an audio mode represents ANC behavior.
bool _isNoiseCancellationMode(AudioMode mode) {
  final normalized = _normalizedModeKey(mode);
  return normalized.contains('noise') || normalized.contains('anc');
}

/// Chooses the icon for an audio mode option.
IconData _iconForMode(AudioMode mode) {
  final normalized = _normalizedModeKey(mode);
  if (normalized.contains('noise') || normalized.contains('anc')) {
    return Icons.volume_off_rounded;
  }
  if (normalized.contains('transparen') ||
      normalized.contains('ambient') ||
      normalized.contains('passthrough')) {
    return Icons.hearing_rounded;
  }
  if (normalized.contains('normal') ||
      normalized.contains('off') ||
      normalized.contains('default')) {
    return Icons.equalizer_rounded;
  }
  return Icons.graphic_eq_rounded;
}

/// Normalizes an audio mode key so different naming styles compare consistently.
String _normalizedModeKey(AudioMode mode) {
  return mode.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
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
