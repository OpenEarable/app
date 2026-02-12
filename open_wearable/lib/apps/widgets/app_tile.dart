import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_wearable/apps/widgets/app_compatibility.dart';
import 'package:open_wearable/apps/widgets/apps_page.dart';
import 'package:open_wearable/models/app_launch_session.dart';

class AppTile extends StatelessWidget {
  final AppInfo app;
  final bool isEnabled;
  final List<String> connectedWearableNames;

  const AppTile({
    super.key,
    required this.app,
    required this.isEnabled,
    required this.connectedWearableNames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderedSupportedDevices = _orderedSupportedDevices(
      app.supportedDevices,
      connectedWearableNames,
    );
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color:
          isEnabled ? theme.textTheme.titleMedium?.color : theme.disabledColor,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled
            ? () {
                AppLaunchSession.markAppFlowOpened();
                Navigator.push(
                  context,
                  platformPageRoute(
                    context: context,
                    builder: (context) => app.widget,
                  ),
                ).whenComplete(AppLaunchSession.markAppFlowClosed);
              }
            : null,
        child: Opacity(
          opacity: isEnabled ? 1 : 0.62,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  height: 62,
                  width: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isEnabled
                          ? app.accentColor.withValues(alpha: 0.28)
                          : theme.disabledColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: app.logoPath.toLowerCase().endsWith('.svg')
                        ? Padding(
                            padding: EdgeInsets.all(app.svgIconInset ?? 10),
                            child: Transform.scale(
                              scale: app.svgIconScale ?? 1,
                              child: SvgPicture.asset(
                                app.logoPath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        : Image.asset(
                            app.logoPath,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              app.title,
                              style: titleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _LaunchAffordance(
                            accentColor: app.accentColor,
                            isEnabled: isEnabled,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        app.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isEnabled
                              ? theme.textTheme.bodyMedium?.color
                              : theme.disabledColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Supported devices',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isEnabled
                              ? theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.72)
                              : theme.disabledColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: orderedSupportedDevices
                            .map(
                              (device) => _SupportedDeviceChip(
                                text: device,
                                isConnected: hasConnectedWearableForPrefix(
                                  devicePrefix: device,
                                  connectedWearableNames:
                                      connectedWearableNames,
                                ),
                                isEnabled: isEnabled,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _orderedSupportedDevices(
    List<String> supportedDevices,
    List<String> connectedWearables,
  ) {
    final connected = <String>[];
    final notConnected = <String>[];

    for (final device in supportedDevices) {
      final isConnected = hasConnectedWearableForPrefix(
        devicePrefix: device,
        connectedWearableNames: connectedWearables,
      );
      if (isConnected) {
        connected.add(device);
      } else {
        notConnected.add(device);
      }
    }

    return [...connected, ...notConnected];
  }
}

class _LaunchAffordance extends StatelessWidget {
  final Color accentColor;
  final bool isEnabled;

  const _LaunchAffordance({
    required this.accentColor,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final disabledColor = Theme.of(context).disabledColor;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      height: 30,
      width: 30,
      decoration: BoxDecoration(
        color: isEnabled
            ? accentColor.withValues(alpha: 0.12)
            : disabledColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 18,
        color: isEnabled
            ? accentColor.withValues(alpha: 0.9)
            : disabledColor.withValues(alpha: 0.9),
      ),
    );
  }
}

class _SupportedDeviceChip extends StatelessWidget {
  final String text;
  final bool isConnected;
  final bool isEnabled;

  const _SupportedDeviceChip({
    required this.text,
    required this.isConnected,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const connectedPillColor = Color(0xFF2E7D32);
    final disabledColor = theme.disabledColor;
    final isConnectedAndEnabled = isEnabled && isConnected;
    final connectedBackgroundColor = connectedPillColor.withValues(alpha: 0.15);
    final isDark = theme.brightness == Brightness.dark;
    final mutedBackgroundColor =
        isDark ? const Color(0xFF3A3F45) : const Color(0xFFE3E7EC);
    final mutedTextColor =
        isDark ? const Color(0xFFD0D5DC) : const Color(0xFF5E6670);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnectedAndEnabled
            ? connectedBackgroundColor
            : isEnabled
                ? mutedBackgroundColor
                : disabledColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isConnectedAndEnabled
                  ? connectedPillColor
                  : isEnabled
                      ? mutedTextColor
                      : disabledColor.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
