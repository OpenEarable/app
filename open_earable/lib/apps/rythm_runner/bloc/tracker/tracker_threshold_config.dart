
class TrackerThresholdConfig {
  final double xThreshold;
  final double zThreshold;
  final double xzThreshold;

  TrackerThresholdConfig({
    required this.xThreshold,
    required this.zThreshold,
    required this.xzThreshold,
  });

  TrackerThresholdConfig copyWith({
    double? xThreshold,
    double? zThreshold,
    double? xzThreshold,
  }) {
    return TrackerThresholdConfig(
      xThreshold: xThreshold ?? this.xThreshold,
      zThreshold: zThreshold ?? this.zThreshold,
      xzThreshold: xzThreshold ?? this.xzThreshold,
    );
  }

  @override
  String toString() => 'TrackerTresholdConfig(xThreshold: $xThreshold, zThreshold: $zThreshold, xzThreshold: $xzThreshold)';

  @override
  bool operator ==(covariant TrackerThresholdConfig other) {
    if (identical(this, other)) return true;
  
    return 
      other.xThreshold == xThreshold &&
      other.zThreshold == zThreshold &&
      other.xzThreshold == xzThreshold;
  }

  @override
  int get hashCode => xThreshold.hashCode ^ zThreshold.hashCode ^ xzThreshold.hashCode;
}
