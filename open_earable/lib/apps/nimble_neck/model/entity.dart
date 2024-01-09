import 'dart:math';

/// Class for providing base functionality for entities
class Entity {
  /// Every Entity must have a unique id
  final String id;

  /// Generates a random unique id if no id is given
  Entity([String? id]) : id = id ?? _generateId();

  /// Generates a random id
  /// Resulting id can be considered unique
  static String _generateId() {
    const length = 32;
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
    final random = Random();

    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}
