import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/wearable_connector.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/widgets/home_page.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' as oe;

import 'models/bluetooth_auto_connector.dart';
import 'view_models/wearables_provider.dart';

// 1) Global navigator key so we can open dialogs from anywhere
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class CustomLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return !(event.message.contains('componentData') ||
        event.message.contains('SensorData') ||
        event.message.contains('Battery'));
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  oe.logger = Logger(level: Level.trace, filter: CustomLogFilter());

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Read provider without listening, allowed in initState with Provider
    final wearablesProvider = context.read<WearablesProvider>();

    _unsupportedFirmwareSub = wearablesProvider.unsupportedFirmwareStream.listen((evt) {
      // No async/await here. No widget context usage either.
      final nav = rootNavigatorKey.currentState;
      if (nav == null || !mounted) return;

      // Push a dialog route via NavigatorState (no BuildContext from this widget)
      nav.push(
        DialogRoute<void>(
          context: rootNavigatorKey.currentContext!, // from navigator, not this widget
          barrierDismissible: true,
          builder: (_) => PlatformAlertDialog(
            title: const Text('Firmware unsupported'),
            content: getUnsupportedAlertText(evt),
            actions: <Widget>[
              PlatformDialogAction(
                cupertino: (_, __) => CupertinoDialogActionData(isDefaultAction: true),
                child: const Text('OK'),
                // Close via navigator state; no widget context
                onPressed: () => rootNavigatorKey.currentState?.pop(),
              ),
            ],
          ),
        ),
      );
    });

    final WearableConnector connector = context.read<WearableConnector>();
    
    final SensorRecorderProvider sensorRecorderProvider = context.read<SensorRecorderProvider>();
    _autoConnector = BluetoothAutoConnector(
      navStateGetter: () => rootNavigatorKey.currentState,
      wearableManager: WearableManager(),
      connector: connector,
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
        builder: (context) => PlatformApp(
          // 3) Attach the navigator key here
          navigatorKey: rootNavigatorKey,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          title: 'Open Wearable',
          home: const HeroMode(
            enabled: false, //TODO: Remove this when Hero animations are fixed
            child: HomePage(),
          ),
        ),
      ),
    );
  }
}
