enum MeditationState {
  mainNeckStretch,
  leftNeckStretch,
  rightNeckStretch,
  noStretch
}

extension MeditationStateExtension on MeditationState {
  String get display {
    switch (this) {
      case MeditationState.mainNeckStretch:
        return 'Main Neck Area';
      case MeditationState.leftNeckStretch:
        return 'Right Neck Area';
      case MeditationState.rightNeckStretch:
        return 'Left Neck Area';
      case MeditationState.noStretch:
        return 'Not Stretching';
      default:
        return 'Invalid State';
    }
  }
}
