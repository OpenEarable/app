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
        title: const Text('Release history'),
      ),
      body: ListView(
        padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
        children: <Widget>[
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
                      highlight.title.replaceAll('\n', ' '),
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
