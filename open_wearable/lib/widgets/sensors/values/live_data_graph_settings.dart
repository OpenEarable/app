import 'package:flutter/material.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';

/// Describes the global rendering policy for live data graphs.
class LiveDataGraphSettings {
  /// Whether live graph widgets should listen to and render incoming samples.
  final bool liveUpdatesEnabled;

  /// Whether graphs without samples should be hidden from the live data views.
  final bool hideGraphsWithoutData;

  const LiveDataGraphSettings({
    required this.liveUpdatesEnabled,
    required this.hideGraphsWithoutData,
  });

  /// Default behavior used before persisted settings have been loaded.
  static const enabled = LiveDataGraphSettings(
    liveUpdatesEnabled: true,
    hideGraphsWithoutData: false,
  );

  /// Builds graph settings from the raw app setting toggles.
  factory LiveDataGraphSettings.fromAppSettings({
    required bool disableLiveDataGraphs,
    required bool hideLiveDataGraphsWithoutData,
  }) {
    return LiveDataGraphSettings(
      liveUpdatesEnabled: !disableLiveDataGraphs,
      hideGraphsWithoutData:
          hideLiveDataGraphsWithoutData && !disableLiveDataGraphs,
    );
  }

  /// Whether a graph with the given data state should be part of the UI.
  bool shouldShowGraph({required bool hasData}) {
    return !hideGraphsWithoutData || hasData;
  }
}

/// Rebuilds descendants when live graph settings change.
class LiveDataGraphSettingsBuilder extends StatelessWidget {
  /// Builds a widget from the current shared live graph settings.
  final Widget Function(BuildContext context, LiveDataGraphSettings settings)
      builder;

  const LiveDataGraphSettingsBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppShutdownSettings.disableLiveDataGraphsListenable,
      builder: (context, disableLiveDataGraphs, _) {
        return ValueListenableBuilder<bool>(
          valueListenable:
              AppShutdownSettings.hideLiveDataGraphsWithoutDataListenable,
          builder: (context, hideLiveDataGraphsWithoutData, __) {
            return builder(
              context,
              LiveDataGraphSettings.fromAppSettings(
                disableLiveDataGraphs: disableLiveDataGraphs,
                hideLiveDataGraphsWithoutData: hideLiveDataGraphsWithoutData,
              ),
            );
          },
        );
      },
    );
  }
}

/// Applies the shared disabled-state treatment around a live graph.
class LiveDataGraphSurface extends StatelessWidget {
  /// Current shared graph settings.
  final LiveDataGraphSettings settings;

  /// Called when the disabled graph overlay is tapped.
  final VoidCallback? onDisabledTap;

  /// The chart surface to decorate.
  final Widget child;

  const LiveDataGraphSurface({
    super.key,
    required this.settings,
    required this.child,
    this.onDisabledTap,
  });

  @override
  Widget build(BuildContext context) {
    if (settings.liveUpdatesEnabled) {
      return child;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 0.5,
          child: child,
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onDisabledTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  onDisabledTap == null
                      ? 'Live graphs disabled'
                      : 'Live graphs disabled. Tap to open settings.',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Placeholder shown when the shared policy hides an empty live graph.
class LiveDataGraphHiddenPlaceholder extends StatelessWidget {
  /// Icon that identifies the hidden graph type.
  final IconData icon;

  /// Primary placeholder text.
  final String title;

  /// Secondary placeholder text.
  final String subtitle;

  /// Called when the placeholder is tapped.
  final VoidCallback onTap;

  const LiveDataGraphHiddenPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
