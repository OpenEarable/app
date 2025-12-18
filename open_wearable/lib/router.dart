import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/heart_tracker_page.dart';
import 'package:open_wearable/apps/posture_tracker/model/earable_attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/view/posture_tracker_view.dart';
import 'package:open_wearable/apps/widgets/select_earable_view.dart';
import 'package:open_wearable/widgets/devices/connect_devices_page.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_page.dart';
import 'package:open_wearable/widgets/fota/firmware_update.dart';
import 'package:open_wearable/widgets/fota/fota_warning_page.dart';
import 'package:open_wearable/widgets/home_page.dart';
import 'package:open_wearable/widgets/logging/log_files_screen.dart';

/// Global navigator key for go_router
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router configuration for the app
final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/connect-devices',
      name: 'connect-devices',
      builder: (context, state) => const ConnectDevicesPage(),
    ),
    GoRoute(
      path: '/device-detail',
      name: 'device-detail',
      builder: (context, state) {
        final device = state.extra as Wearable;
        return DeviceDetailPage(device: device);
      },
    ),
    GoRoute(
      path: '/log-files',
      name: 'log-files',
      builder: (context, state) => const LogFilesScreen(),
    ),
    GoRoute(
      path: '/fota-warning',
      name: 'fota-warning',
      builder: (context, state) => const FotaWarningPage(),
    ),
    GoRoute(
      path: '/firmware-update',
      name: 'firmware-update',
      builder: (context, state) => const FirmwareUpdateWidget(),
    ),
    GoRoute(
      path: '/select-earable-posture',
      name: 'select-earable-posture',
      builder: (context, state) => SelectEarableView(
        startApp: (wearable, sensorConfigProvider) {
          return PostureTrackerView(
            EarableAttitudeTracker(
              wearable as SensorManager,
              sensorConfigProvider,
              wearable.name.endsWith("L"),
            ),
          );
        },
      ),
    ),
    GoRoute(
      path: '/select-earable-heart',
      name: 'select-earable-heart',
      builder: (context, state) => SelectEarableView(
        startApp: (wearable, _) {
          if (wearable is SensorManager) {
            Sensor ppgSensor = (wearable as SensorManager).sensors.firstWhere(
              (s) => s.sensorName.toLowerCase() == "photoplethysmography".toLowerCase(),
            );
            return HeartTrackerPage(ppgSensor: ppgSensor);
          }
          return const Scaffold(
            body: Center(
              child: Text("No PPG Sensor Found"),
            ),
          );
        },
      ),
    ),
  ],
);
