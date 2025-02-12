import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/widgets/home_page.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' as oe;

import 'view_models/wearables_provider.dart';

class CustomLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return !(
      event.message.contains('componentData') ||
      event.message.contains('SensorData') ||
      event.message.contains('Battery')
    );
  }
}

void main() {
  oe.logger = Logger(level: Level.trace, filter: CustomLogFilter());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => WearablesProvider()),
        ChangeNotifierProvider(create: (context) => SensorConfigurationProvider(),)
      ],
      child: const MyApp()
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return PlatformProvider(
      builder: (context) => 
        PlatformTheme(
          materialLightTheme: ThemeData(
            useMaterial3: true, // Enables Material You (Pixel UI)
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            cardTheme: CardTheme(
              color: Colors.white,
              elevation: 0, // Subtle shadow
            ),
          ),
          builder: (context) => PlatformApp(
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            title: 'Open Wearable',
            home: HomePage(),
        ),
      ),
    );
  }
}
