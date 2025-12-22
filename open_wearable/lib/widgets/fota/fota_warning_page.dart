import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';

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
      
      if (device != null && device is BatteryLevelStatus) {
        // Get the current battery level from the stream
        final batteryLevel = await (device as BatteryLevelStatus)
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
      } else {
        if (mounted) {
          setState(() {
            _checkingBattery = false;
          });
        }
      }
    } catch (e) {
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } else {
      throw 'Could not launch $uri';
    }
  }

  void _handleProceed() {
    if (_currentBatteryLevel == null) {
      // Battery level could not be determined
      showPlatformDialog(
        context: context,
        builder: (_) => PlatformAlertDialog(
          title: const Text('Battery Level Unknown'),
          content: Text(
            'Unable to determine the OpenEarable battery level. '
            'For safety, please ensure your OpenEarable is charged to at least $_minimumBatteryThreshold% before proceeding with the firmware update.\n\n'
            'Do you want to proceed anyway?',
          ),
          actions: <Widget>[
            PlatformDialogAction(
              cupertino: (_, __) => CupertinoDialogActionData(),
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            PlatformDialogAction(
              cupertino: (_, __) => CupertinoDialogActionData(
                isDestructiveAction: true,
              ),
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
      // Show first warning dialog with option to force update
      _showLowBatteryWarning();
    } else {
      context.push('/fota/update');
    }
  }

  void _showLowBatteryWarning() {
    showPlatformDialog(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Battery Level Too Low'),
        content: Text(
          'Your OpenEarable battery level is $_currentBatteryLevel%, which is below the required $_minimumBatteryThreshold% minimum for firmware updates.\n\n'
          'Updating with low battery can cause the update to fail and may result in a bricked device.\n\n'
          'It is strongly recommended to charge your device before proceeding.',
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
            cupertino: (_, __) => CupertinoDialogActionData(
              isDestructiveAction: true,
            ),
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
        title: const Text('Critical Warning'),
        content: Text(
          'FINAL WARNING: Proceeding with a firmware update at $_currentBatteryLevel% battery may permanently brick your OpenEarable device.\n\n'
          'You will not be able to recover the device if the update fails due to low battery.\n\n'
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
            cupertino: (_, __) => CupertinoDialogActionData(
              isDestructiveAction: true,
            ),
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
    final textTheme = theme.textTheme;
    final baseTextStyle = textTheme.bodyLarge; // one place to define size

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Firmware Update'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: DefaultTextStyle.merge( // <<– base style for everything
                style: baseTextStyle ?? const TextStyle(fontSize: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with warning icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Warning',
                          style: (baseTextStyle ?? const TextStyle())
                              .copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: (baseTextStyle?.fontSize ?? 16) + 2,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // First paragraph with hyperlink
                    Text.rich(
                      TextSpan(
                        style: baseTextStyle,
                        children: [
                          const TextSpan(
                            text:
                                'Updating OpenEarable via Bluetooth is currently an experimental feature. '
                                'Hence, updating OpenEarable over Bluetooth might sometimes not complete successfully. '
                                'If that happens, you can easily perform a manual update with the help of a J-Link debugger (see ',
                          ),
                          TextSpan(
                            text: 'GitHub instructions',
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = _openGitHubLink,
                          ),
                          const TextSpan(text: ').'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'To help ensure a smooth update, please:',
                      style: baseTextStyle?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Steps in a Card
                    Card(
                      elevation: 2,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _NumberedStep(
                              number: '1.',
                              text: TextSpan(
                                text:
                                    'Power cycle your OpenEarable once before you update.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            const _NumberedStep(
                              number: '2.',
                              text: TextSpan(
                                text:
                                    'Keep the app open in the foreground and make sure your phone doesn’t enter power-saving mode.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            _NumberedStep(
                              number: '3.',
                              text: TextSpan(
                                text:
                                    'Ensure your OpenEarable has at least $_minimumBatteryThreshold% battery charge before starting. Fully charging is recommended.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            const _NumberedStep(
                              number: '4.',
                              text: TextSpan(
                                text: "Keep OpenEarable disconnected from charger during the update.",
                              ),
                            ),
                            const SizedBox(height: 8),
                            const _NumberedStep(
                              number: '5.',
                              text: TextSpan(
                                text:
                                    'If you have two devices, power off the one that’s not being updated.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            const _NumberedStep(
                              number: '6.',
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        'After the firmware is uploaded, OpenEarable will automatically verify it. '
                                        'During this step, the device might seem unresponsive for up to 3 minutes. '
                                        'Don’t worry, this is normal. It will start blinking again once the process is complete.\n',
                                  ),
                                  TextSpan(
                                    text:
                                        'Don‘t reset the device via the button while the firmware is verified by OpenEarable.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Battery level warning if below 50%
                    if (_currentBatteryLevel != null && _currentBatteryLevel! < _minimumBatteryThreshold)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                          border: Border.all(
                            color: theme.colorScheme.error,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.battery_alert,
                              color: theme.colorScheme.error,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Battery level is $_currentBatteryLevel%. Please charge to at least $_minimumBatteryThreshold% before updating.',
                                style: baseTextStyle?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Battery level warning if unknown
                    if (!_checkingBattery && _currentBatteryLevel == null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.orange,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.battery_unknown,
                              color: Colors.orange,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Unable to determine battery level. Please ensure your device is charged to at least $_minimumBatteryThreshold%.',
                                style: baseTextStyle?.copyWith(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Proceed button
                    SizedBox(
                      width: double.infinity,
                      child: _checkingBattery
                          ? const Center(child: CircularProgressIndicator())
                          : PlatformElevatedButton(
                              onPressed: _handleProceed,
                              child: const Text('Acknowledge and Proceed'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget for cleanly aligned numbered steps
class _NumberedStep extends StatelessWidget {
  final String number;
  final InlineSpan text; // now accepts TextSpan / InlineSpan

  const _NumberedStep({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: baseStyle,
              children: [text],
            ),
          ),
        ),
      ],
    );
  }
}
