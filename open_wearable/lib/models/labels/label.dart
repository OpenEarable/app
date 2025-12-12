import 'package:flutter/material.dart';

/// A single label with a name and a color.
class Label {
  final String name;
  final Color color;

  const Label({
    required this.name,
    required this.color,
  });

  /// Create a modified copy (useful for editing).
  Label copyWith({
    String? name,
    Color? color,
  }) {
    return Label(
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  /// JSON -> Label
  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      name: json['name'] as String,
      color: Color(int.parse(json['color'] as String)),
    );
  }

  /// Label -> JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': '0x${color.toARGB32().toRadixString(16)}',
    };
  }
}
