import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_wearable/apps/widgets/app_compatibility.dart';
import 'package:open_wearable/apps/widgets/apps_page.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

class AppTile extends StatelessWidget {
  final AppInfo app;

  const AppTile({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final connectedWearableNames = context
        .watch<WearablesProvider>()
        .wearables
        .map((wearable) => wearable.name)
        .toList(growable: false);
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            platformPageRoute(
              context: context,
              builder: (context) => app.widget,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                height: 62.0,
                width: 62.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: app.accentColor.withValues(alpha: 0.28),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13.0),
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
                        _LaunchAffordance(accentColor: app.accentColor),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      app.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supported devices',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: app.supportedDevices
                          .map(
                            (device) => _SupportedDeviceChip(
                              text: device,
                              accentColor: app.accentColor,
                              isConnected: hasConnectedWearableForPrefix(
                                devicePrefix: device,
                                connectedWearableNames: connectedWearableNames,
                              ),
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
    );
  }
}

class _LaunchAffordance extends StatelessWidget {
  final Color accentColor;

  const _LaunchAffordance({
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      height: 30,
      width: 30,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 18,
        color: accentColor.withValues(alpha: 0.9),
      ),
    );
  }
}

class _SupportedDeviceChip extends StatelessWidget {
  final String text;
  final Color accentColor;
  final bool isConnected;

  const _SupportedDeviceChip({
    required this.text,
    required this.accentColor,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    const connectedDotColor = Color(0xFF2F8F5B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accentColor.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (isConnected) ...[
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: connectedDotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
