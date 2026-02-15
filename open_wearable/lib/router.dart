import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/devices/connect_devices_page.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_page.dart';
import 'package:open_wearable/widgets/fota/firmware_update.dart';
import 'package:open_wearable/widgets/fota/fota_warning_page.dart';
import 'package:open_wearable/widgets/home_page.dart';
import 'package:open_wearable/widgets/logging/log_files_screen.dart';
import 'package:open_wearable/widgets/settings/connectors_page.dart';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// Global navigator key for go_router
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

int _parseHomeSectionIndex(String? tabParam) {
  if (tabParam == null || tabParam.isEmpty) {
    return 0;
  }

  switch (tabParam.toLowerCase()) {
    case 'overview':
      return 0;
    case 'devices':
      return 1;
    case 'sensors':
      return 2;
    case 'apps':
      return 3;
    case 'settings':
      return 4;
    default:
      final parsed = int.tryParse(tabParam);
      if (parsed == null || parsed < 0 || parsed > 4) {
        return 0;
      }
      return parsed;
  }
}

/// Router configuration for the app
final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) {
        final initialSection = _parseHomeSectionIndex(
          state.uri.queryParameters['tab'],
        );
        return HeroMode(
          enabled: false,
          child: HomePage(initialSectionIndex: initialSection),
        );
      },
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
      path: '/connectors',
      name: 'connectors',
      builder: (context, state) => const ConnectorsPage(),
    ),
    GoRoute(
      path: '/fota',
      name: 'fota',
      redirect: (context, state) {
        final bool isAndroid = !kIsWeb && Platform.isAndroid;
        final bool isIOS = !kIsWeb && Platform.isIOS;

        if (!isAndroid && !isIOS) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = rootNavigatorKey.currentContext;
            if (ctx == null) return;

            showPlatformDialog(
              context: ctx,
              builder: (_) => PlatformAlertDialog(
                title: PlatformText('Firmware Update'),
                content: PlatformText(
                  'Firmware update is not supported on this platform. '
                  'Please use an Android device or J-Link to update the firmware.',
                ),
                actions: <Widget>[
                  PlatformDialogAction(
                    cupertino: (_, __) => CupertinoDialogActionData(
                      isDefaultAction: true,
                    ),
                    child: PlatformText('OK'),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            );
          });

          return state.topRoute?.name;
        }

        return null;
      },
      builder: (context, state) => const FotaWarningPage(),
    ),
    GoRoute(
      path: '/fota/update',
      name: 'fota/update',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        child: const FirmwareUpdateWidget(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved);

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
      ),
    ),
  ],
);
