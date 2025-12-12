// A set of labels, identified by a name.
import 'label.dart';

class LabelSet {
  final String name;
  final List<Label> labels;

  LabelSet({
    required this.name,
    required List<Label> labels,
  }) : labels = List.unmodifiable(labels);

  /// Create a modified copy (e.g., renamed set, updated labels list).
  LabelSet copyWith({
    String? name,
    List<Label>? labels,
  }) {
    return LabelSet(
      name: name ?? this.name,
      labels: labels ?? this.labels,
    );
  }

  /// JSON -> LabelSet
  factory LabelSet.fromJson(Map<String, dynamic> json) {
    final labelsJson = json['labels'] as List<dynamic>? ?? [];
    return LabelSet(
      name: json['name'] as String,
      labels: labelsJson
          .map((e) => Label.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// LabelSet -> JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'labels': labels.map((l) => l.toJson()).toList(),
    };
  }
}
