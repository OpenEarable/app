import '../configs/demo_mode_config.dart';

enum MeditationPromptPolicy {
  standard(
    includeProfileInformation: true,
    includePhysiologicalInformation: true,
  ),
  conferenceDemo(
    includeProfileInformation: DemoModeConfig.includePermanentProfileInPrompt,
    includePhysiologicalInformation:
        DemoModeConfig.includePhysiologicalDataInPrompt,
  );

  final bool includeProfileInformation;
  final bool includePhysiologicalInformation;

  const MeditationPromptPolicy({
    required this.includeProfileInformation,
    required this.includePhysiologicalInformation,
  });
}
