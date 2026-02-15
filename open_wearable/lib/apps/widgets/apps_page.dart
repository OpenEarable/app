import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/heart_tracker_page.dart';
import 'package:open_wearable/apps/posture_tracker/model/earable_attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/view/posture_tracker_view.dart';
import 'package:open_wearable/apps/self_test/self_test_page.dart';
import 'package:open_wearable/apps/widgets/app_compatibility.dart';
import 'package:open_wearable/apps/widgets/select_earable_view.dart';
import 'package:open_wearable/apps/widgets/app_tile.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:provider/provider.dart';

class AppInfo {
  final String logoPath;
  final String title;
  final String description;
  final List<String> supportedDevices;
  final Color accentColor;
  final Widget widget;
  final double? svgIconInset;
  final double? svgIconScale;
  final Color? iconBackgroundColor;

  AppInfo({
    required this.logoPath,
    required this.title,
    required this.description,
    required this.supportedDevices,
    required this.accentColor,
    required this.widget,
    this.svgIconInset,
    this.svgIconScale,
    this.iconBackgroundColor,
  });
}

const Color _appAccentColor = Color(0xFF9A6F6B);
const List<String> _postureSupportedDevices = [
  "OpenEarable",
];
const List<String> _heartSupportedDevices = [
  "OpenEarable",
];
const List<String> _selfTestSupportedDevices = [
  "OpenEarable",
];

final List<AppInfo> _apps = [
  AppInfo(
    logoPath: "lib/apps/posture_tracker/assets/logo.png",
    title: "Posture Tracker",
    description: "Get feedback on bad posture",
    supportedDevices: _postureSupportedDevices,
    accentColor: _appAccentColor,
    widget: SelectEarableView(
      supportedDevicePrefixes: _postureSupportedDevices,
      startApp: (wearable, sensorConfigProvider) {
        return PostureTrackerView(
          EarableAttitudeTracker(
            wearable.requireCapability<SensorManager>(),
            sensorConfigProvider,
            wearable.name.endsWith("L"),
          ),
        );
      },
    ),
  ),
  AppInfo(
    logoPath: "lib/apps/heart_tracker/assets/logo.png",
    title: "Heart Tracker",
    description: "Track your heart rate and other vitals",
    supportedDevices: _heartSupportedDevices,
    accentColor: _appAccentColor,
    widget: SelectEarableView(
      supportedDevicePrefixes: _heartSupportedDevices,
      startApp: (wearable, _) {
        if (wearable.hasCapability<SensorManager>()) {
          final sensors = wearable.requireCapability<SensorManager>().sensors;
          final ppgSensor = sensors.firstWhere(
            (s) =>
                s.sensorName.toLowerCase() ==
                'photoplethysmography'.toLowerCase(),
          );

          Sensor? accelerometerSensor;
          for (final sensor in sensors) {
            final text =
                '${sensor.sensorName} ${sensor.chartTitle}'.toLowerCase();
            if (text.contains('accelerometer') || text.contains('acc')) {
              accelerometerSensor = sensor;
              break;
            }
          }

          return HeartTrackerPage(
            ppgSensor: ppgSensor,
            accelerometerSensor: accelerometerSensor,
          );
        }
        return PlatformScaffold(
          appBar: PlatformAppBar(
            title: PlatformText("Heart Tracker"),
          ),
          body: Center(
            child: PlatformText("No PPG Sensor Found"),
          ),
        );
      },
    ),
  ),
  AppInfo(
    logoPath: "lib/apps/self_test/assets/self_test_icon.svg",
    title: "Device Self Test",
    description: "Run guided OpenEarable hardware checks with a test report",
    supportedDevices: _selfTestSupportedDevices,
    accentColor: _appAccentColor,
    svgIconInset: 0,
    svgIconScale: 1.14,
    iconBackgroundColor: const Color(0xFFF0E6E4),
    widget: SelectEarableView(
      supportedDevicePrefixes: _selfTestSupportedDevices,
      startApp: (wearable, sensorConfigProvider) {
        return SelfTestPage(
          wearable: wearable,
          sensorConfigProvider: sensorConfigProvider,
        );
      },
    ),
  ),
];

int getAvailableAppsCount() => _apps.length;

int getCompatibleAppsCountForWearables(Iterable<Wearable> wearables) {
  final names = wearables.map((wearable) => wearable.name).toList();
  if (names.isEmpty) return 0;

  return _apps.where((app) {
    return names.any(
      (name) => wearableIsCompatibleWithApp(
        wearableName: name,
        supportedDevicePrefixes: app.supportedDevices,
      ),
    );
  }).length;
}

class AppsPage extends StatelessWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final connectedCount = context.watch<WearablesProvider>().wearables.length;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("Apps"),
        trailingActions: [
          const AppBarRecordingIndicator(),
          PlatformIconButton(
            icon: Icon(context.platformIcons.bluetooth),
            onPressed: () {
              context.push('/connect-devices');
            },
          ),
        ],
      ),
      body: ListView(
        padding: SensorPageSpacing.pagePadding,
        children: [
          _AppsHeroCard(
            totalApps: _apps.length,
            connectedDevices: connectedCount,
          ),
          const SizedBox(height: SensorPageSpacing.sectionGap),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'Available apps',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ..._apps.map((app) => AppTile(app: app)),
        ],
      ),
    );
  }
}

class _AppsHeroCard extends StatelessWidget {
  final int totalApps;
  final int connectedDevices;

  const _AppsHeroCard({
    required this.totalApps,
    required this.connectedDevices,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF835B58),
            Color(0xFFB48A86),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'App Studio',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Launch wearable experiences from one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroStatPill(
                label: '$totalApps apps',
                icon: Icons.widgets_outlined,
              ),
              _HeroStatPill(
                label: '$connectedDevices wearables connected',
                icon: Icons.link_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeroStatPill({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
