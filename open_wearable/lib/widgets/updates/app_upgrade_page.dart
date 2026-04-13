import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/models/app_upgrade_highlight.dart';

/// Full-screen page that presents a custom "what's new" experience.
class AppUpgradePage extends StatelessWidget {
  /// Creates the post-upgrade page.
  const AppUpgradePage({
    super.key,
    required this.highlight,
    this.onContinue,
  });

  /// Upgrade content rendered by this page.
  final AppUpgradeHighlight highlight;

  /// Invoked when the user dismisses the page.
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accentColor = highlight.accentColor ?? colorScheme.primary;
    final VoidCallback dismiss =
        onContinue ?? () => Navigator.of(context).maybePop();

    return PlatformScaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colorScheme.surfaceContainerLowest,
              colorScheme.surfaceContainerLow,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool useTwoColumns = constraints.maxWidth >= 980;
              return Stack(
                children: <Widget>[
                  Positioned(
                    top: -40,
                    right: -20,
                    child: _GlowOrb(
                      color: accentColor.withValues(alpha: 0.16),
                      size: 220,
                    ),
                  ),
                  Positioned(
                    top: 120,
                    left: -50,
                    child: _GlowOrb(
                      color: colorScheme.tertiary.withValues(alpha: 0.12),
                      size: 170,
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: dismiss,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Skip'),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Center(
                          child: useTwoColumns
                              ? _WideUpgradeLayout(
                                  highlight: highlight,
                                  accentColor: accentColor,
                                  onContinue: dismiss,
                                )
                              : _CompactUpgradeLayout(
                                  highlight: highlight,
                                  accentColor: accentColor,
                                  onContinue: dismiss,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompactUpgradeLayout extends StatelessWidget {
  const _CompactUpgradeLayout({
    required this.highlight,
    required this.accentColor,
    required this.onContinue,
  });

  final AppUpgradeHighlight highlight;
  final Color accentColor;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _UpgradeHeroCard(highlight: highlight, accentColor: accentColor),
        const SizedBox(height: 16),
        ...highlight.features.map(
          (AppUpgradeFeatureHighlight feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _UpgradeFeatureCard(
              feature: feature,
              accentColor: accentColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _UpgradeFooter(
          featureCount: highlight.features.length,
          onContinue: onContinue,
        ),
      ],
    );
  }
}

class _WideUpgradeLayout extends StatelessWidget {
  const _WideUpgradeLayout({
    required this.highlight,
    required this.accentColor,
    required this.onContinue,
  });

  final AppUpgradeHighlight highlight;
  final Color accentColor;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final List<Widget> featureCards = highlight.features
        .map(
          (AppUpgradeFeatureHighlight feature) => _UpgradeFeatureCard(
            feature: feature,
            accentColor: accentColor,
          ),
        )
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 10,
          child: _UpgradeHeroCard(
            highlight: highlight,
            accentColor: accentColor,
            expanded: true,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 12,
          child: Column(
            children: <Widget>[
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: featureCards,
              ),
              const SizedBox(height: 12),
              _UpgradeFooter(
                featureCount: highlight.features.length,
                onContinue: onContinue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpgradeHeroCard extends StatelessWidget {
  const _UpgradeHeroCard({
    required this.highlight,
    required this.accentColor,
    this.expanded = false,
  });

  final AppUpgradeHighlight highlight;
  final Color accentColor;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(minHeight: expanded ? 520 : 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accentColor.withValues(alpha: 0.20),
              colorScheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _HeroBadge(label: highlight.eyebrow, accentColor: accentColor),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeroAppIcon(accentColor: accentColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          highlight.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          highlight.summary,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                highlight.heroDescription,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _HeroPill(
                    icon: Icons.new_releases_outlined,
                    label: 'Version ${highlight.version}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeFeatureCard extends StatelessWidget {
  const _UpgradeFeatureCard({
    required this.feature,
    required this.accentColor,
  });

  final AppUpgradeFeatureHighlight feature;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    accentColor.withValues(alpha: 0.18),
                    colorScheme.secondaryContainer.withValues(alpha: 0.55),
                  ],
                ),
              ),
              child: Icon(feature.icon, color: accentColor),
            ),
            const SizedBox(height: 14),
            Text(
              feature.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              feature.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeFooter extends StatelessWidget {
  const _UpgradeFooter({
    required this.featureCount,
    required this.onContinue,
  });

  final int featureCount;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Ready to explore?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$featureCount update highlights are ready. Continue into the app when you are done.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.accentColor,
  });

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: colorScheme.primary),
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

class _HeroAppIcon extends StatelessWidget {
  const _HeroAppIcon({
    required this.accentColor,
  });

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accentColor.withValues(alpha: 0.22),
            colorScheme.secondaryContainer.withValues(alpha: 0.76),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}
