/// Web stub: the treadmill unit needs local file storage that is unavailable on
/// web. Exists only so the study protocol UI compiles for the web target.
Future<String> saveTreadmillWalkingPace({
  required String directory,
  required String probandId,
  required double walkingPaceKmh,
  DateTime? recordedAt,
}) {
  throw UnsupportedError('Treadmill pace storage is unavailable on web');
}
