import 'package:flutter/material.dart';

/// Describes a single feature highlight shown in the post-upgrade experience.
class AppUpgradeFeatureHighlight {
  /// Creates a feature highlight.
  const AppUpgradeFeatureHighlight({
    required this.icon,
    required this.title,
    required this.description,
  });

  /// Leading icon rendered inside the feature card.
  final IconData icon;

  /// Short feature title.
  final String title;

  /// Short feature description.
  final String description;
}

/// Defines the content for a specific app upgrade announcement.
class AppUpgradeHighlight {
  /// Creates version-specific upgrade content.
  const AppUpgradeHighlight({
    required this.version,
    required this.eyebrow,
    required this.title,
    required this.summary,
    required this.heroDescription,
    required this.features,
    this.accentColor,
  });

  /// App version for which the content should be shown.
  final String version;

  /// Small label shown above the hero title.
  final String eyebrow;

  /// Main hero title.
  final String title;

  /// Short summary line shown near the hero.
  final String summary;

  /// Longer introduction for the upgrade.
  final String heroDescription;

  /// Highlight cards rendered in the page body.
  final List<AppUpgradeFeatureHighlight> features;

  /// Optional accent color used to tint the hero surface.
  final Color? accentColor;
}
