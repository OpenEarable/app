// A named group of labels.
import 'label.dart';

class LabelGroup {
  final String name;
  final List<Label> labels;

  const LabelGroup({
    required this.name,
    required this.labels,
  });

  /// Create a modified copy (e.g., renamed group, updated label list).
  LabelGroup copyWith({
    String? name,
    List<Label>? labels,
  }) {
    return LabelGroup(
      name: name ?? this.name,
      labels: labels ?? this.labels,
    );
  }

  /// JSON -> LabelGroup
  factory LabelGroup.fromJson(Map<String, dynamic> json) {
    final labelsJson = json['labels'] as List<dynamic>? ?? [];
    return LabelGroup(
      name: json['name'] as String,
      labels: labelsJson
          .map((e) => Label.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// LabelGroup -> JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'labels': labels.map((l) => l.toJson()).toList(),
    };
  }
}
