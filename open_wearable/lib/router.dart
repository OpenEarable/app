import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
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
        if (state.extra == null || state.extra is! Wearable) {
          // Fallback to home if device is not provided
          return const HomePage();
        }
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
      path: '/fota',
      name: 'fota',
      builder: (context, state) => const FotaWarningPage(),
    ),
    GoRoute(
      path: '/fota/update',
      name: 'fota/update',
      builder: (context, state) => const FirmwareUpdateWidget(),
    ),
  ],
);
