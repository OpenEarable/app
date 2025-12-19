import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/models/log_file_manager.dart';
import 'package:open_wearable/models/wearable_connector.dart';
import 'package:open_wearable/router.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/widgets/app_banner.dart';
import 'package:open_wearable/widgets/global_app_banner_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/bluetooth_auto_connector.dart';
import 'models/logger.dart';
import 'view_models/app_banner_controller.dart';
import 'view_models/label_provider.dart';
import 'view_models/label_set_provider.dart';
import 'view_models/wearables_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogFileManager logFileManager = await LogFileManager.create();
  initOpenWearableLogger(logFileManager.libLogger);
  initLogger(logFileManager.logger);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => WearablesProvider()),
        ChangeNotifierProvider(
          create: (context) => FirmwareUpdateRequestProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => SensorRecorderProvider(),
        ),
        Provider.value(value: WearableConnector()),
        ChangeNotifierProvider(
          create: (context) => AppBannerController(),
        ),
        ChangeNotifierProvider.value(value: logFileManager),
        ChangeNotifierProvider(
          create: (context) => LabelSetProvider(),
        ),
        ChangeNotifierProxyProvider<LabelSetProvider, LabelProvider>(
          create: (context) => LabelProvider(null),
          update: (context, labelSetProvider, labelProvider) {
            labelProvider?.setLabelSet(labelSetProvider.selectedLabelSet);
            return labelProvider!;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

// 2) Make MyApp stateful so we can subscribe once to provider events
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final StreamSubscription _unsupportedFirmwareSub;
  late final StreamSubscription _wearableEventSub;
  late final BluetoothAutoConnector _autoConnector;
  late final Future<SharedPreferences> _prefsFuture;
  late final StreamSubscription _wearableProvEventSub;

  @override
  void initState() {
    super.initState();
    _prefsFuture = SharedPreferences.getInstance();
    WidgetsBinding.instance.addObserver(this);

    // Read provider without listening, allowed in initState with Provider
    final wearablesProvider = context.read<WearablesProvider>();

    _unsupportedFirmwareSub =
        wearablesProvider.unsupportedFirmwareStream.listen((evt) {
      // No async/await here. No widget context usage either.
      final nav = rootNavigatorKey.currentState;
      if (nav == null || !mounted) return;

      // Push a dialog route via NavigatorState (no BuildContext from this widget)
      nav.push(
        DialogRoute<void>(
          context: rootNavigatorKey
              .currentContext!, // from navigator, not this widget
          barrierDismissible: true,
          builder: (_) => PlatformAlertDialog(
            title: const Text('Firmware unsupported'),
            content: getUnsupportedAlertText(evt),
            actions: <Widget>[
              PlatformDialogAction(
                cupertino: (_, __) =>
                    CupertinoDialogActionData(isDefaultAction: true),
                child: const Text('OK'),
                // Close via navigator state; no widget context
                onPressed: () => rootNavigatorKey.currentState?.pop(),
              ),
            ],
          ),
        ),
      );
    });

    _wearableProvEventSub = wearablesProvider.wearableEventStream.listen((event) {
      if (!mounted) return;

      // Handle firmware update available events with a dialog
      if (event is NewFirmwareAvailableEvent) {
        final nav = rootNavigatorKey.currentState;
        if (nav == null || !mounted) return;

        nav.push(
          DialogRoute<void>(
            context: rootNavigatorKey.currentContext!,
            barrierDismissible: true,
            builder: (dialogContext) => PlatformAlertDialog(
              title: const Text('Firmware Update Available'),
              content: Text(
                'A newer firmware version (${event.latestVersion}) is available. You are using version ${event.currentVersion}.',
              ),
              actions: [
                PlatformDialogAction(
                  cupertino: (_, __) => CupertinoDialogActionData(),
                  child: const Text('Later'),
                  onPressed: () => rootNavigatorKey.currentState?.pop(),
                ),
                PlatformDialogAction(
                  cupertino: (_, __) =>
                      CupertinoDialogActionData(isDefaultAction: true),
                  child: const Text('Update Now'),
                  onPressed: () {
                    // Set the selected peripheral for firmware update
                    final updateProvider = Provider.of<FirmwareUpdateRequestProvider>(
                      rootNavigatorKey.currentContext!,
                      listen: false,
                    );
                    updateProvider.setSelectedPeripheral(event.wearable);
                    rootNavigatorKey.currentState?.pop();
                    rootNavigatorKey.currentContext?.push('/fota');
                  },
                ),
              ],
            ),
          ),
        );
        return;
      }

      // Show a banner for other events using AppBannerController
      final appBannerController = context.read<AppBannerController>();
      appBannerController.showBanner(
        (id) {
          late final Color backgroundColor;
          if (event is WearableErrorEvent) {
            backgroundColor = Theme.of(context).colorScheme.error;
          } else {
            backgroundColor = Theme.of(context).colorScheme.primary;
          }

          late final Color textColor;
          if (event is WearableErrorEvent) {
            textColor = Theme.of(context).colorScheme.onError;
          } else {
            textColor = Theme.of(context).colorScheme.onPrimary;
          }

          return AppBanner(
            content: Text(
              event.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor,
              ),
            ),
            backgroundColor: backgroundColor,
            key: ValueKey(id),
          );
        },
        duration: const Duration(seconds: 3),
      );
    });

    final WearableConnector connector = context.read<WearableConnector>();

    final SensorRecorderProvider sensorRecorderProvider =
        context.read<SensorRecorderProvider>();
    _autoConnector = BluetoothAutoConnector(
      navStateGetter: () => rootNavigatorKey.currentState,
      wearableManager: WearableManager(),
      connector: connector,
      prefsFuture: _prefsFuture,
      onWearableConnected: (wearable) {
        wearablesProvider.addWearable(wearable);
        sensorRecorderProvider.addWearable(wearable);
      },
    );

    _wearableEventSub = connector.events.listen((event) {
      if (event is WearableConnectEvent) {
        wearablesProvider.addWearable(event.wearable);
        sensorRecorderProvider.addWearable(event.wearable);
      }
    });

    _autoConnector.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _autoConnector.start();
    } else if (state == AppLifecycleState.paused) {
      _autoConnector.stop();
    }
  }

  Text getUnsupportedAlertText(UnsupportedFirmwareEvent evt) {
    if (evt is FirmwareTooOldEvent) {
      return const Text(
        'The device has a firmware version that is too old and not supported by this app. '
        'Please update the device firmware to ensure all features are working as expected.',
      );
    } else if (evt is FirmwareTooNewEvent) {
      return const Text(
        'The device has a firmware version that is too new and not supported by this app. '
        'Please update the app to ensure all features are working as expected.',
      );
    } else {
      return const Text(
        'The device has a firmware unsupported by this app. '
        'Please update the app and Firmware to the newest version to ensure all features are working as expected.',
      );
    }
  }

  @override
  void dispose() {
    _unsupportedFirmwareSub.cancel();
    _wearableEventSub.cancel();
    _wearableProvEventSub.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _autoConnector.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformProvider(
      settings: PlatformSettingsData(
        iosUsesMaterialWidgets: true,
      ),
      builder: (context) => PlatformTheme(
        materialLightTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 0,
          ),
        ),
        builder: (context) => GlobalAppBannerOverlay(
          child: PlatformApp.router(
            routerConfig: router,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            title: 'Open Wearable',
          ),
        ),
      ),
    );
  }
}
