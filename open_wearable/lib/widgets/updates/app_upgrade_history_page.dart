import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_wearable/models/app_upgrade_highlight.dart';
import 'package:open_wearable/models/app_upgrade_registry.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

/// Lists all registered upgrade highlights so older releases can be revisited.
class AppUpgradeHistoryPage extends StatelessWidget {
  /// Creates the upgrade history page.
  const AppUpgradeHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<AppUpgradeHighlight> highlights = AppUpgradeRegistry.all;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Release highlights'),
      ),
      body: ListView(
        padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
        children: <Widget>[
          _HistoryIntroCard(highlightCount: highlights.length),
          const SizedBox(height: 8),
          ...highlights.map(
            (AppUpgradeHighlight highlight) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HighlightHistoryCard(highlight: highlight),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryIntroCard extends StatelessWidget {
  const _HistoryIntroCard({
    required this.highlightCount,
  });

  final int highlightCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Browse release stories',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open the current release page or revisit older version highlights.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _HistoryPill(
                  icon: Icons.history_rounded,
                  label: '$highlightCount registered releases',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightHistoryCard extends StatelessWidget {
  const _HighlightHistoryCard({
    required this.highlight,
  });

  final AppUpgradeHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accentColor = highlight.accentColor ?? colorScheme.primary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/whats-new?version=${highlight.version}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: accentColor.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.new_releases_rounded,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Version ${highlight.version}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      highlight.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      highlight.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryPill extends StatelessWidget {
  const _HistoryPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
