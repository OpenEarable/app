import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onLogsRequested;
  final VoidCallback onConnectRequested;
  final VoidCallback onGeneralSettingsRequested;

  const SettingsPage({
    super.key,
    required this.onLogsRequested,
    required this.onConnectRequested,
    required this.onGeneralSettingsRequested,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Settings'),
        trailingActions: [
          const AppBarRecordingIndicator(),
          PlatformIconButton(
            icon: Icon(context.platformIcons.bluetooth),
            onPressed: onConnectRequested,
          ),
        ],
      ),
      body: ListView(
        padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
        children: [
          _QuickActionTile(
            icon: Icons.tune_rounded,
            title: 'General settings',
            subtitle: 'Manage app-wide behavior',
            onTap: onGeneralSettingsRequested,
          ),
          _QuickActionTile(
            icon: Icons.receipt_long,
            title: 'Log files',
            subtitle: 'View, share, and remove diagnostic logs',
            onTap: onLogsRequested,
          ),
          _QuickActionTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'App information, version, and licenses',
            onTap: () => context.push('/view', extra: const _AboutPage()),
          ),
        ],
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  static final Uri _repoUri = Uri.parse('https://github.com/OpenEarable/app');
  static final Uri _tecoUri = Uri.parse('https://teco.edu');
  static final Uri _openWearablesUri = Uri.parse('https://openwearables.com');
  static const String _aboutAttribution =
      'The OpenWearables App is developed and maintained by the TECO research group at the Karlsruhe Institute of Technology and OpenWearables GmbH.';

  Future<void> _openExternalUrl(
    BuildContext context, {
    required Uri uri,
    required String label,
  }) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) {
      return;
    }

    AppToast.show(
      context,
      message: 'Could not open $label.',
      type: AppToastType.error,
      icon: Icons.link_off_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'OpenWearables App',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _aboutAttribution,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'Made with'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            child: Icon(
                              Icons.favorite,
                              size: 15,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const TextSpan(text: 'in Karlsruhe, Germany.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AboutExternalLink(
                        icon: Icons.code_rounded,
                        title: 'Source Code',
                        urlText: 'github.com/OpenEarable/app',
                        onTap: () => _openExternalUrl(
                          context,
                          uri: _repoUri,
                          label: 'GitHub repository',
                        ),
                      ),
                      const SizedBox(height: 6),
                      _AboutExternalLink(
                        icon: Icons.school_outlined,
                        title: 'TECO Research Group',
                        urlText: 'teco.edu',
                        onTap: () => _openExternalUrl(
                          context,
                          uri: _tecoUri,
                          label: 'teco.edu',
                        ),
                      ),
                      const SizedBox(height: 6),
                      _AboutExternalLink(
                        icon: Icons.language_rounded,
                        title: 'OpenWearables GmbH',
                        urlText: 'openwearables.com',
                        trailing: const _OpenWearablesFloatingBadge(),
                        onTap: () => _openExternalUrl(
                          context,
                          uri: _openWearablesUri,
                          label: 'openwearables.com',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Privacy & Data Protection',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Designed for transparency and control.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _PrivacyChecklistItem(
                    text: 'Only data required for app features is processed.',
                  ),
                  const SizedBox(height: 8),
                  const _PrivacyChecklistItem(
                    text: 'Recorded data stays on your device by default.',
                  ),
                  const SizedBox(height: 8),
                  const _PrivacyChecklistItem(
                    text:
                        'Export and sharing happen only when you explicitly choose it.',
                  ),
                  const SizedBox(height: 8),
                  const _PrivacyChecklistItem(
                    text:
                        'Diagnostic logs are shared only through manual user action.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Open source licenses'),
              subtitle: const Text('View third-party software licenses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/view',
                extra: const _OpenSourceLicensesPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenSourceLicensesPage extends StatefulWidget {
  const _OpenSourceLicensesPage();

  @override
  State<_OpenSourceLicensesPage> createState() =>
      _OpenSourceLicensesPageState();
}

class _OpenSourceLicensesPageState extends State<_OpenSourceLicensesPage> {
  late final Future<List<_PackageLicenseEntry>> _licensesFuture =
      _loadLicenses();

  Future<List<_PackageLicenseEntry>> _loadLicenses() async {
    final byPackage = <String, Set<String>>{};

    await for (final entry in LicenseRegistry.licenses) {
      final licenseText = entry.paragraphs.map((p) => p.text).join('\n').trim();
      if (licenseText.isEmpty) {
        continue;
      }

      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => <String>{}).add(licenseText);
      }
    }

    final items = byPackage.entries
        .map(
          (entry) => _PackageLicenseEntry(
            packageName: entry.key,
            licenseTexts: entry.value.toList(growable: false),
          ),
        )
        .toList()
      ..sort(
        (a, b) => a.packageName.toLowerCase().compareTo(
              b.packageName.toLowerCase(),
            ),
      );

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Open source licenses'),
      ),
      body: FutureBuilder<List<_PackageLicenseEntry>>(
        future: _licensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load licenses.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final licenses = snapshot.data ?? const <_PackageLicenseEntry>[];

          return ListView(
            padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why this list exists',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The OpenWearables App uses third-party open source software. '
                        'This list provides the required license notices and '
                        'credits for those dependencies.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (licenses.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Text(
                      'No licenses found.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final item in licenses) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          12,
                        ),
                        shape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                        ),
                        collapsedShape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                        ),
                        title: Text(
                          item.packageName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${item.licenseTexts.length} license text${item.licenseTexts.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        children: [
                          for (var i = 0;
                              i < item.licenseTexts.length;
                              i++) ...[
                            SelectableText(
                              item.licenseTexts[i],
                              style: theme.textTheme.bodySmall,
                            ),
                            if (i < item.licenseTexts.length - 1) ...[
                              const SizedBox(height: 10),
                              Divider(
                                height: 1,
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _PackageLicenseEntry {
  final String packageName;
  final List<String> licenseTexts;

  const _PackageLicenseEntry({
    required this.packageName,
    required this.licenseTexts,
  });
}

class _AboutExternalLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String urlText;
  final Widget? trailing;
  final VoidCallback onTap;

  const _AboutExternalLink({
    required this.icon,
    required this.title,
    required this.urlText,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      urlText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenWearablesFloatingBadge extends StatelessWidget {
  const _OpenWearablesFloatingBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeBorderRadius = BorderRadius.circular(999);
    return ClipRRect(
      borderRadius: badgeBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            5,
            5,
            9,
            5,
          ),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(69, 69, 69, 0.40),
            borderRadius: badgeBorderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF2FB26F),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF5ED394),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'OpenWearables',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: theme.textTheme.labelSmall?.fontSize ?? 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyChecklistItem extends StatelessWidget {
  final String text;

  const _PrivacyChecklistItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const checkColor = Color(0xFF2E7D32);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: checkColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
