import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/models/log_file_manager.dart';
import 'package:open_wearable/models/connector_settings.dart';
import 'package:open_wearable/models/fota_post_update_verification.dart';
import 'package:open_wearable/models/wearable_connector.dart'
    hide WearableEvent;
import 'package:open_wearable/router.dart';
import 'package:open_wearable/theme/app_theme.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/widgets/app_banner.dart';
import 'package:open_wearable/widgets/global_app_banner_overlay.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/fota/fota_verification_banner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/bluetooth_auto_connector.dart';
import 'models/logger.dart';
import 'view_models/app_banner_controller.dart';
import 'view_models/wearables_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogFileManager logFileManager = await LogFileManager.create();
  initOpenWearableLogger(logFileManager.libLogger);
  initLogger(logFileManager.logger);
  await ConnectorSettings.initialize();

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
  late final WearablesProvider _wearablesProvider;
  late final SensorRecorderProvider _sensorRecorderProvider;

  @override
  void initState() {
    super.initState();
    _prefsFuture = SharedPreferences.getInstance();
    WidgetsBinding.instance.addObserver(this);

    // Read provider without listening, allowed in initState with Provider
    _wearablesProvider = context.read<WearablesProvider>();
    _sensorRecorderProvider = context.read<SensorRecorderProvider>();

    _unsupportedFirmwareSub =
        _wearablesProvider.unsupportedFirmwareStream.listen((evt) {
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

    _wearableProvEventSub =
        _wearablesProvider.wearableEventStream.listen((event) {
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
                    final updateProvider =
                        Provider.of<FirmwareUpdateRequestProvider>(
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
          final colorScheme = Theme.of(context).colorScheme;
          final bool isError = event is WearableErrorEvent;
          final bool isTimeSync = event is WearableTimeSynchronizedEvent;
          const timeSyncBackground = Color(0xFFEDE4FF);
          const timeSyncForeground = Color(0xFF5A2EA6);
          final backgroundColor = isError
              ? colorScheme.errorContainer
              : isTimeSync
                  ? timeSyncBackground
                  : colorScheme.primaryContainer;
          final textColor = isError
              ? colorScheme.onErrorContainer
              : isTimeSync
                  ? timeSyncForeground
                  : colorScheme.onPrimaryContainer;
          final icon = isError
              ? Icons.error_outline_rounded
              : isTimeSync
                  ? Icons.schedule_rounded
                  : Icons.info_outline_rounded;
          final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              );

          return AppBanner(
            content: _buildBannerContent(
              event: event,
              textColor: textColor,
              textStyle: textStyle,
              accentColor: textColor,
            ),
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            leadingIcon: icon,
            key: ValueKey(id),
          );
        },
        duration: const Duration(seconds: 4),
      );
    });

    final WearableConnector connector = context.read<WearableConnector>();

    _autoConnector = BluetoothAutoConnector(
      navStateGetter: () => rootNavigatorKey.currentState,
      wearableManager: WearableManager(),
      connector: connector,
      prefsFuture: _prefsFuture,
      onWearableConnected: _handleWearableConnected,
    );

    _wearableEventSub = connector.events.listen((event) {
      if (event is WearableConnectEvent) {
        _handleWearableConnected(event.wearable);
      }
    });

    _autoConnector.start();
  }

  void _handleWearableConnected(Wearable wearable) {
    _wearablesProvider.addWearable(wearable);
    _sensorRecorderProvider.addWearable(wearable);
    _maybeFinalizePostUpdateVerification(wearable);
  }

  Future<void> _maybeFinalizePostUpdateVerification(Wearable wearable) async {
    final result = await FotaPostUpdateVerificationCoordinator.instance
        .verifyOnWearableConnected(wearable);
    if (!mounted || result == null) {
      return;
    }

    dismissFotaVerificationBannerById(context, result.verificationId);
    final accentColor = result.success
        ? const Color(0xFF1E6A3A)
        : Theme.of(context).colorScheme.onErrorContainer;
    AppToast.showContent(
      context,
      content: _buildPostUpdateVerificationToastContent(
        result: result,
        accentColor: accentColor,
      ),
      type: result.success ? AppToastType.success : AppToastType.error,
      icon:
          result.success ? Icons.verified_rounded : Icons.error_outline_rounded,
      duration: result.success
          ? const Duration(seconds: 6)
          : const Duration(seconds: 8),
    );
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

  Widget _buildPostUpdateVerificationToastContent({
    required FotaPostUpdateVerificationResult result,
    required Color accentColor,
  }) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: accentColor,
          fontWeight: FontWeight.w700,
        );
    final detailStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: accentColor,
          fontWeight: FontWeight.w600,
        );

    final detailText = _verificationToastDetail(result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: baseStyle,
            children: [
              TextSpan(text: result.wearableName),
              if (result.sideLabel != null) const TextSpan(text: ' '),
              if (result.sideLabel != null)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _ToastStereoSideBadge(
                    sideLabel: result.sideLabel!,
                    accentColor: accentColor,
                  ),
                ),
              TextSpan(
                text: result.success
                    ? ' updated successfully.'
                    : ' verification failed.',
              ),
            ],
          ),
        ),
        if (detailText != null) ...[
          const SizedBox(height: 4),
          Text(detailText, style: detailStyle),
        ],
      ],
    );
  }

  String? _verificationToastDetail(FotaPostUpdateVerificationResult result) {
    if (result.success) {
      final version = result.detectedFirmwareVersion;
      if (version == null) {
        return null;
      }
      return 'Firmware version: $version';
    }

    final detected = result.detectedFirmwareVersion;
    final expected = result.expectedFirmwareVersion;

    if (detected == null) {
      return 'Could not read firmware version. Keep the earable powered on and do not reset.';
    }

    if (expected == null) {
      return 'Expected firmware version is unknown (detected $detected). Do not reset or power off.';
    }

    return 'Expected $expected, detected $detected. Do not reset or power off.';
  }

  Widget _buildBannerContent({
    required WearableEvent event,
    required Color textColor,
    required Color accentColor,
    TextStyle? textStyle,
  }) {
    final resolvedTextStyle = textStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ) ??
        TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        );

    if (event is! WearableTimeSynchronizedEvent) {
      return Text(event.description, style: resolvedTextStyle);
    }

    final parsed = _ParsedStereoSyncMessage.tryParse(event.description);
    if (parsed == null) {
      return Text(event.description, style: resolvedTextStyle);
    }

    return Text.rich(
      TextSpan(
        style: resolvedTextStyle,
        children: [
          if (parsed.prefix.isNotEmpty) TextSpan(text: '${parsed.prefix} '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _ToastStereoSideBadge(
              sideLabel: parsed.sideLabel,
              accentColor: accentColor,
            ),
          ),
          if (parsed.suffix.isNotEmpty) TextSpan(text: ' ${parsed.suffix}'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _unsupportedFirmwareSub.cancel();
    _wearableEventSub.cancel();
    _wearableProvEventSub.cancel();
    ConnectorSettings.dispose();
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
        materialLightTheme: AppTheme.lightTheme(),
        materialDarkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.light,
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

class _ParsedStereoSyncMessage {
  final String prefix;
  final String sideLabel;
  final String suffix;

  const _ParsedStereoSyncMessage({
    required this.prefix,
    required this.sideLabel,
    required this.suffix,
  });

  static _ParsedStereoSyncMessage? tryParse(String message) {
    final match = RegExp(r'\((Left|Right)\)').firstMatch(message);
    if (match == null) return null;

    final sideWord = match.group(1);
    final sideLabel = switch (sideWord) {
      'Left' => 'L',
      'Right' => 'R',
      _ => null,
    };
    if (sideLabel == null) return null;

    final prefix = message.substring(0, match.start).trimRight();
    final suffix = message.substring(match.end).trimLeft();

    return _ParsedStereoSyncMessage(
      prefix: prefix,
      sideLabel: sideLabel,
      suffix: suffix,
    );
  }
}

class _ToastStereoSideBadge extends StatelessWidget {
  final String sideLabel;
  final Color accentColor;

  const _ToastStereoSideBadge({
    required this.sideLabel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = accentColor;
    final background = foreground.withValues(alpha: 0.16);
    final border = foreground.withValues(alpha: 0.34);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        sideLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
      ),
    );
  }
}
