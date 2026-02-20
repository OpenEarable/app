import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_profile_service.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_config_option_icon_factory.dart';

enum ProfileDetailStatus {
  notSelected,
  selected,
  applied,
  mixed,
  unavailable,
}

class ProfileDetailEntry {
  final String configName;
  final ProfileDetailStatus status;
  final String? samplingLabel;
  final List<SensorConfigurationOption> dataTargetOptions;
  final String? detailText;

  const ProfileDetailEntry({
    required this.configName,
    required this.status,
    this.samplingLabel,
    this.dataTargetOptions = const [],
    this.detailText,
  });
}

class ProfileApplicationBadge extends StatelessWidget {
  final ProfileApplicationState state;

  const ProfileApplicationBadge({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    const appliedGreen = Color(0xFF2E7D32);
    final colorScheme = Theme.of(context).colorScheme;
    final (label, foreground, background, border) = switch (state) {
      ProfileApplicationState.selected => (
          'Selected',
          colorScheme.primary,
          colorScheme.primary.withValues(alpha: 0.10),
          colorScheme.primary.withValues(alpha: 0.30),
        ),
      ProfileApplicationState.applied => (
          'Applied',
          appliedGreen,
          appliedGreen.withValues(alpha: 0.12),
          appliedGreen.withValues(alpha: 0.34),
        ),
      ProfileApplicationState.mixed => (
          'Mixed',
          colorScheme.error,
          colorScheme.error.withValues(alpha: 0.12),
          colorScheme.error.withValues(alpha: 0.34),
        ),
      ProfileApplicationState.none => (
          '',
          colorScheme.onSurfaceVariant,
          Colors.transparent,
          Colors.transparent,
        ),
    };

    if (state == ProfileApplicationState.none) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class ProfileDetailCard extends StatelessWidget {
  final ProfileDetailEntry entry;

  const ProfileDetailCard({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final neutralAccent = colorScheme.onSurfaceVariant;
    final indicatorColor = colorScheme.outlineVariant.withValues(alpha: 0.72);
    final icon = switch (entry.status) {
      ProfileDetailStatus.mixed => Icons.sync_problem_rounded,
      ProfileDetailStatus.unavailable => Icons.warning_amber_outlined,
      _ => Icons.sensors_rounded,
    };
    final showMixedBubble = entry.status == ProfileDetailStatus.mixed;
    final showValueBubbles =
        !showMixedBubble && entry.status != ProfileDetailStatus.unavailable;
    final showHelperText = entry.detailText != null &&
        (entry.status == ProfileDetailStatus.notSelected ||
            entry.status == ProfileDetailStatus.mixed ||
            entry.status == ProfileDetailStatus.unavailable);
    final titleColor = colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 2,
              height: 30,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              icon,
              size: 15,
              color: neutralAccent,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          entry.configName,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      if (showMixedBubble) ...[
                        const SizedBox(width: 8),
                        const ProfileMixedStateBubble(),
                      ] else if (showValueBubbles &&
                          entry.dataTargetOptions.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ProfileOptionsCompactBadge(
                          options: entry.dataTargetOptions,
                          accentColor: neutralAccent,
                        ),
                      ],
                      if (showValueBubbles && entry.samplingLabel != null) ...[
                        const SizedBox(width: 8),
                        ProfileSamplingRatePill(
                          label: entry.samplingLabel!,
                          foreground: neutralAccent,
                        ),
                      ],
                    ],
                  ),
                  if (showHelperText) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.detailText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileOptionsCompactBadge extends StatelessWidget {
  final List<SensorConfigurationOption> options;
  final Color accentColor;

  const ProfileOptionsCompactBadge({
    super.key,
    required this.options,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleCount = options.length > 2 ? 2 : options.length;
    final remainingCount = options.length - visibleCount;

    return SizedBox(
      height: 22,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.38),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < visibleCount; i++) ...[
              Icon(
                getSensorConfigurationOptionIcon(options[i]) ??
                    Icons.tune_rounded,
                size: 10,
                color: accentColor,
              ),
              if (i < visibleCount - 1) const SizedBox(width: 3),
            ],
            if (remainingCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '+$remainingCount',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileSamplingRatePill extends StatelessWidget {
  final String label;
  final Color foreground;

  const ProfileSamplingRatePill({
    super.key,
    required this.label,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 22,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: foreground.withValues(alpha: 0.42),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 38),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class ProfileMixedStateBubble extends StatelessWidget {
  const ProfileMixedStateBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 22,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.82),
          ),
        ),
        child: Text(
          'Mixed',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class CombinedStereoBadge extends StatelessWidget {
  const CombinedStereoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = colorScheme.primary;
    final backgroundColor = foregroundColor.withValues(alpha: 0.12);
    final borderColor = foregroundColor.withValues(alpha: 0.24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        'L+R',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
      ),
    );
  }
}

class InsetSectionDivider extends StatelessWidget {
  const InsetSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(
              alpha: 0.55,
            ),
      ),
    );
  }
}
