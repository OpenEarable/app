import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
      final device = updateProvider.updateParameters.peripheral;
      
      if (device != null && device is BatteryLevelStatus) {
        // Get the current battery level from the stream
        final batteryLevel = await (device as BatteryLevelStatus)
            .batteryPercentageStream
            .first
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => null,
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
    if (_currentBatteryLevel != null && _currentBatteryLevel! < 50) {
      // Show error dialog
      showPlatformDialog(
        context: context,
        builder: (_) => PlatformAlertDialog(
          title: const Text('Battery Level Too Low'),
          content: Text(
            'Your OpenEarable battery level is ${_currentBatteryLevel}%, which is below the required 50% minimum for firmware updates.\n\n'
            'Please charge your OpenEarable to at least 50% before attempting a firmware update to prevent issues during the update process.',
          ),
          actions: <Widget>[
            PlatformDialogAction(
              cupertino: (_, __) => CupertinoDialogActionData(
                isDefaultAction: true,
              ),
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } else {
      context.push('/fota/update');
    }
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
                          children: const [
                            _NumberedStep(
                              number: '1.',
                              text: TextSpan(
                                text:
                                    'Power cycle your OpenEarable once before you update.',
                              ),
                            ),
                            SizedBox(height: 8),
                            _NumberedStep(
                              number: '2.',
                              text: TextSpan(
                                text:
                                    'Keep the app open in the foreground and make sure your phone doesn’t enter power-saving mode.',
                              ),
                            ),
                            SizedBox(height: 8),
                            _NumberedStep(
                              number: '3.',
                              text: TextSpan(
                                text:
                                    'Ensure your OpenEarable has at least 50% battery charge before starting. Fully charging is recommended.',
                              ),
                            ),
                            SizedBox(height: 8),
                            _NumberedStep(
                              number: '4.',
                              text: TextSpan(
                                text: "Keep OpenEarable disconnected from charger during the update.",
                              ),
                            ),
                            SizedBox(height: 8),
                            _NumberedStep(
                              number: '5.',
                              text: TextSpan(
                                text:
                                    'If you have two devices, power off the one that’s not being updated.',
                              ),
                            ),
                            SizedBox(height: 8),
                            _NumberedStep(
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
                    if (_currentBatteryLevel != null && _currentBatteryLevel! < 50)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.1),
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
                                'Battery level is ${_currentBatteryLevel}%. Please charge to at least 50% before updating.',
                                style: baseTextStyle?.copyWith(
                                  color: theme.colorScheme.error,
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
