/// A class representing a platform in the Doodle Jump game.
///
/// The platform has a position defined by [x] and [y] coordinates,
/// and dimensions defined by [width] and [height].
class Platform {
  double x;
  double y;
  final double width;
  final double height;

  Platform({
    required this.x,
    required this.y,
    this.width = 100,
    this.height = 20,
  });
}
