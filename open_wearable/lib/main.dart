import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/widgets/home_page.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' as oe;

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

class _MyAppState extends State<MyApp> {
  StreamSubscription? _unsupportedFirmwareSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Avoid re-subscribing on hot reload
    _unsupportedFirmwareSub ??=
        context.read<WearablesProvider>().unsupportedFirmwareStream.listen((evt) async {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      if (!mounted) return;

      // Guard context usage with mounted check after async gap
      await showPlatformDialog(
        context: ctx,
        builder: (_) => PlatformAlertDialog(
          title: const Text('Firmware nicht unterstützt'),
          content: Text(
            'The device "${evt.wearable.name}" has a firmware unsupported by this app. '
            'Please update the app to ensure all features are working as expected.',
          ),
          actions: <Widget>[
            PlatformDialogAction(
              cupertino: (_, __) => CupertinoDialogActionData(isDefaultAction: true),
              child: const Text('OK'),
              onPressed: () {
                if (!mounted) return;
                Navigator.of(ctx, rootNavigator: true).pop();
              },
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _unsupportedFirmwareSub?.cancel();
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
