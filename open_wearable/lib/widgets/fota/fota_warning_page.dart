import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class FotaWarningPage extends StatefulWidget {
  const FotaWarningPage({super.key});

  @override
  State<FotaWarningPage> createState() => _FotaWarningPageState();
}

class _FotaWarningPageState extends State<FotaWarningPage> {
  static const int _minimumBatteryThreshold = 50;

  int? _currentBatteryLevel;
  bool _checkingBattery = true;

  @override
  void initState() {
    super.initState();
    _checkBatteryLevel();
  }

  Future<void> _checkBatteryLevel() async {
    try {
      final updateProvider = Provider.of<FirmwareUpdateRequestProvider>(
        context,
        listen: false,
      );
      final device = updateProvider.selectedWearable;

      if (device != null && device.hasCapability<BatteryLevelStatus>()) {
        final batteryLevel = await device
            .requireCapability<BatteryLevelStatus>()
            .batteryPercentageStream
            .first
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => 0,
            );

        if (mounted) {
          setState(() {
            _currentBatteryLevel = batteryLevel;
            _checkingBattery = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _checkingBattery = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingBattery = false;
        });
      }
    }
  }

  Future<void> _openGitHubLink() async {
    final uri = Uri.parse(
      'https://github.com/OpenEarable/open-earable-2?tab=readme-ov-file#setup',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open GitHub instructions.'),
      ),
    );
  }

  void _handleProceed() {
    if (_currentBatteryLevel == null) {
      showPlatformDialog(
        context: context,
        builder: (_) => PlatformAlertDialog(
          title: const Text('Battery level unknown'),
          content: Text(
            'Unable to read the current battery level.\n\n'
            'Please make sure your OpenEarable is charged to at least '
            '$_minimumBatteryThreshold% before continuing.\n\n'
            'Do you want to proceed anyway?',
          ),
          actions: <Widget>[
            PlatformDialogAction(
              cupertino: (_, __) => CupertinoDialogActionData(),
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            PlatformDialogAction(
              cupertino: (_, __) =>
                  CupertinoDialogActionData(isDestructiveAction: true),
              child: const Text('Proceed Anyway'),
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/fota/update');
              },
            ),
          ],
        ),
      );
    } else if (_currentBatteryLevel! < _minimumBatteryThreshold) {
      _showLowBatteryWarning();
    } else {
      context.push('/fota/update');
    }
  }

  void _showLowBatteryWarning() {
    showPlatformDialog(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Battery level too low'),
        content: Text(
          'Your OpenEarable battery level is $_currentBatteryLevel%, which is '
          'below the recommended $_minimumBatteryThreshold% for firmware updates.\n\n'
          'Updating with low battery can fail and may leave the device unusable, requiring recovery with a J-Link debugger.\n\n'
          'Please charge your device before continuing.',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            cupertino: (_, __) => CupertinoDialogActionData(
              isDefaultAction: true,
            ),
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          PlatformDialogAction(
            cupertino: (_, __) =>
                CupertinoDialogActionData(isDestructiveAction: true),
            child: const Text('Force Update Anyway'),
            onPressed: () {
              Navigator.of(context).pop();
              _showFinalBrickingWarning();
            },
          ),
        ],
      ),
    );
  }

  void _showFinalBrickingWarning() {
    showPlatformDialog(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Critical warning'),
        content: Text(
          'FINAL WARNING: Proceeding with $_currentBatteryLevel% battery can '
          'cause the update to fail and leave your OpenEarable unusable until it is recovered with a J-Link debugger.\n\n'
          'Are you absolutely sure you want to continue?',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            cupertino: (_, __) => CupertinoDialogActionData(
              isDefaultAction: true,
            ),
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          PlatformDialogAction(
            cupertino: (_, __) =>
                CupertinoDialogActionData(isDestructiveAction: true),
            child: const Text('I Understand, Proceed'),
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/fota/update');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Update Instructions'),
      ),
      body: ListView(
        padding: SensorPageSpacing.pagePadding,
        children: [
          _SectionCard(
            title: 'Before You Update',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WarningPill(
                  label: 'Bluetooth firmware updates are experimental.',
                ),
                const SizedBox(height: 10),
                Text(
                  'Following the steps below ensures that updates will not fail. '
                  'In the unlikely event that an update fails, the device must be recovered with a J-Link debugger.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openGitHubLink,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open GitHub Recovery Instructions'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SensorPageSpacing.sectionGap),
          _SectionCard(
            title: 'Checklist',
            subtitle: 'Please confirm these points before continuing.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ChecklistItem(
                  number: 1,
                  text:
                      'Power cycle your OpenEarable once before starting the update.',
                ),
                const SizedBox(height: 8),
                const _ChecklistItem(
                  number: 2,
                  text:
                      'Keep the app open in the foreground and disable power-saving mode.',
                ),
                const SizedBox(height: 8),
                _ChecklistItem(
                  number: 3,
                  text:
                      'Ensure at least $_minimumBatteryThreshold% battery before updating. Full charge is recommended.',
                ),
                const SizedBox(height: 8),
                const _ChecklistItem(
                  number: 4,
                  text: 'Keep OpenEarable disconnected from the charger.',
                ),
                const SizedBox(height: 8),
                const _ChecklistItem(
                  number: 5,
                  text:
                      'If you have two devices, power off the one that is not being updated.',
                ),
                const SizedBox(height: 8),
                const _ChecklistItem(
                  number: 6,
                  text:
                      'After upload, verification can take up to 3 minutes and is indicated by a blinking red LED. Do not reset during verification, or you may brick it.',
                  boldFragment: 'Do not reset during verification',
                ),
              ],
            ),
          ),
          const SizedBox(height: SensorPageSpacing.sectionGap),
          _buildBatteryCard(context),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _checkingBattery ? null : _handleProceed,
              icon: _checkingBattery
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                _checkingBattery
                    ? 'Checking Battery...'
                    : 'Acknowledge and Proceed',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_checkingBattery) {
      return _SectionCard(
        title: 'Battery Status',
        subtitle: 'Checking current battery level...',
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reading battery level from the device.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_currentBatteryLevel == null) {
      return _SectionCard(
        title: 'Battery Status',
        subtitle: 'Battery level could not be determined.',
        child: _StatusNotice(
          icon: Icons.battery_unknown_rounded,
          text:
              'Please ensure your device is charged to at least $_minimumBatteryThreshold% before updating.',
          foregroundColor: colorScheme.tertiary,
          backgroundColor: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
          borderColor: colorScheme.tertiary.withValues(alpha: 0.45),
        ),
      );
    }

    final batteryLevel = _currentBatteryLevel!;
    final low = batteryLevel < _minimumBatteryThreshold;

    return _SectionCard(
      title: 'Battery Status',
      subtitle: low
          ? 'Battery is below the recommended update threshold.'
          : 'Battery level is sufficient for update.',
      child: _StatusNotice(
        icon: low ? Icons.battery_alert_rounded : Icons.battery_charging_full,
        text: low
            ? 'Battery level is $batteryLevel%. Please charge to at least $_minimumBatteryThreshold% before updating.'
            : 'Battery level is $batteryLevel%. You can proceed with the update.',
        foregroundColor: low ? colorScheme.error : colorScheme.primary,
        backgroundColor: low
            ? colorScheme.errorContainer.withValues(alpha: 0.45)
            : colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderColor: low
            ? colorScheme.error.withValues(alpha: 0.5)
            : colorScheme.primary.withValues(alpha: 0.35),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _WarningPill extends StatelessWidget {
  final String label;

  const _WarningPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foreground.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 15,
            color: foreground,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              softWrap: true,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final int number;
  final String text;
  final String? boldFragment;

  const _ChecklistItem({
    required this.number,
    required this.text,
    this.boldFragment,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final numberColor = colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: numberColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: numberColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildText(context),
        ),
      ],
    );
  }

  Widget _buildText(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    if (boldFragment == null || boldFragment!.isEmpty) {
      return Text(
        text,
        style: baseStyle,
      );
    }

    final start = text.indexOf(boldFragment!);
    if (start < 0) {
      return Text(
        text,
        style: baseStyle,
      );
    }

    final end = start + boldFragment!.length;
    final before = text.substring(0, start);
    final bold = text.substring(start, end);
    final after = text.substring(end);

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(
            text: bold,
            style: baseStyle?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  const _StatusNotice({
    required this.icon,
    required this.text,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
