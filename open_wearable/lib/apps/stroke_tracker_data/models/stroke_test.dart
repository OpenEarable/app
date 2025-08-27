class StrokeTest {
  final String id;
  final String title;
  final String description;

  final Duration? recordingDuration;

  final String? explainerVideoAsset;


  StrokeTest({
    required this.id,
    required this.title,
    required this.description,
    this.recordingDuration,
    this.explainerVideoAsset,
  });
}
