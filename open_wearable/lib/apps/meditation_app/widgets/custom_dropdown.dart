import 'package:flutter/material.dart';
import '../configs/overall_config.dart';
import '../model/user_account.dart'
    show
        Gender,
        SpeakingSpeed,
        MeditationType,
        MeditationEnvironment,
        TtsProviderOption,
        TencentTtsRegion;
import '../widgets/emojis.dart';

final voiceGenderOptions = [
  DropdownMenuEntry(
    value: Gender.female,
    label: '${AppEmojis.female} Female',
  ),
  DropdownMenuEntry(
    value: Gender.male,
    label: '${AppEmojis.male} Male',
  ),
];
final speakingSpeedOptions = SpeakingSpeed.values.map((option) {
  return DropdownMenuEntry(
    value: option,
    label:
        '${option.emoji} ${option.label} ${option.isRecommended ? "(Recommended)" : ""}',
  );
}).toList();
final meditationTypeOptions = MeditationType.values.map((type) {
  return DropdownMenuEntry(
    value: type,
    label: '${type.emoji} ${type.label}',
  );
}).toList();
final meditationEnvironmentOptions = MeditationEnvironment.values.map((env) {
  return DropdownMenuEntry(
    value: env,
    label: '${env.emoji} ${env.label}',
  );
}).toList();
final ttsProviderOptions = TtsProviderOption.values.map((provider) {
  return DropdownMenuEntry(
    value: provider,
    label: provider.label,
  );
}).toList();
final tencentTtsRegionOptions = TencentTtsRegion.values.map((region) {
  return DropdownMenuEntry(
    value: region,
    label: region.label,
  );
}).toList();
final stressThresholdOptions = [
  DropdownMenuEntry(
    value: OverallMeditationConfig.verySensitiveStressSensitivity,
    label: '${AppEmojis.chart} 5% - Very Sensitive',
  ),
  DropdownMenuEntry(
    value: OverallMeditationConfig.defaultStressSensitivity,
    label: '${AppEmojis.chart} 10% - Recommended',
  ),
  DropdownMenuEntry(
    value: OverallMeditationConfig.moderateStressSensitivity,
    label: '${AppEmojis.chart} 15% - Moderate',
  ),
  DropdownMenuEntry(
    value: OverallMeditationConfig.lessSensitiveStressSensitivity,
    label: '${AppEmojis.chart} 20% - Less Sensitive',
  ),
];

class FormDropdown<T> extends StatelessWidget {
  final T initialSelection;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?> onSelected;
  final double? menuHeight;

  const FormDropdown({
    super.key,
    required this.initialSelection,
    required this.entries,
    required this.onSelected,
    this.menuHeight,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T>(
      initialSelection: initialSelection,
      expandedInsets: EdgeInsets.zero,
      menuHeight: menuHeight,
      dropdownMenuEntries: entries,
      onSelected: (T? value) {
        if (value != null) {
          onSelected(value);
        }
      },
    );
  }
}

class VoiceGenderDropdown extends StatelessWidget {
  final Gender initialSelection;
  final ValueChanged<Gender?> onSelected;

  const VoiceGenderDropdown({
    super.key,
    required this.initialSelection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => FormDropdown<Gender>(
        initialSelection: initialSelection,
        entries: voiceGenderOptions,
        onSelected: onSelected,
      );
}

class SpeakingSpeedDropdown extends StatelessWidget {
  final SpeakingSpeed initialSelection;
  final ValueChanged<SpeakingSpeed?> onSelected;

  const SpeakingSpeedDropdown({
    super.key,
    required this.initialSelection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => FormDropdown<SpeakingSpeed>(
        initialSelection: initialSelection,
        entries: speakingSpeedOptions,
        onSelected: onSelected,
      );
}

class MeditationTypeDropdown extends StatelessWidget {
  final MeditationType initialSelection;
  final ValueChanged<MeditationType?> onSelected;

  const MeditationTypeDropdown({
    super.key,
    required this.initialSelection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => FormDropdown<MeditationType>(
        initialSelection: initialSelection,
        entries: meditationTypeOptions,
        onSelected: onSelected,
      );
}

class MeditationEnvironmentDropdown extends StatelessWidget {
  final MeditationEnvironment initialSelection;
  final ValueChanged<MeditationEnvironment?> onSelected;

  const MeditationEnvironmentDropdown({
    super.key,
    required this.initialSelection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => FormDropdown<MeditationEnvironment>(
        initialSelection: initialSelection,
        entries: meditationEnvironmentOptions,
        onSelected: onSelected,
      );
}

class StressThresholdDropdown extends StatelessWidget {
  final double initialSelection;
  final ValueChanged<double?> onSelected;

  const StressThresholdDropdown({
    super.key,
    required this.initialSelection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => FormDropdown<double>(
        initialSelection: initialSelection,
        entries: stressThresholdOptions,
        onSelected: onSelected,
      );
}

class TtsProviderDropdown extends StatelessWidget {
  final TtsProviderOption initialSelection;
  final ValueChanged<TtsProviderOption?> onSelected;

  const TtsProviderDropdown({
    super.key,
    required this.initialSelection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => FormDropdown<TtsProviderOption>(
        initialSelection: initialSelection,
        entries: ttsProviderOptions,
        onSelected: onSelected,
      );
}

class TencentTtsRegionDropdown extends StatelessWidget {
  final TencentTtsRegion initialSelection;
  final ValueChanged<TencentTtsRegion?> onSelected;

  const TencentTtsRegionDropdown({
    super.key,
    required this.initialSelection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => FormDropdown<TencentTtsRegion>(
        initialSelection: initialSelection,
        entries: tencentTtsRegionOptions,
        onSelected: onSelected,
      );
}

class ElevenLabsVoiceDropdown extends StatelessWidget {
  static const String _codedDefaultValue = '';

  final List<({String voice, String id})> voices;
  final String? initialSelection;
  final ValueChanged<String?> onSelected;

  const ElevenLabsVoiceDropdown({
    super.key,
    required this.voices,
    required this.initialSelection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FormDropdown<String>(
      initialSelection: initialSelection ?? _codedDefaultValue,
      menuHeight: 300,
      entries: [
        const DropdownMenuEntry(
          value: _codedDefaultValue,
          label: 'Default voice (configured in app)',
        ),
        ...voices.map(
          (voice) => DropdownMenuEntry(value: voice.id, label: voice.voice),
        ),
      ],
      onSelected: (value) =>
          onSelected(value == _codedDefaultValue ? null : value),
    );
  }
}
