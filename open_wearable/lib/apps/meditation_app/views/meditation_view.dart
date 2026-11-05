import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import '../model/user_account.dart';
import '../model/meditation_analytics.dart';
import '../model/meditation_service_settings_store.dart';
import '../model/meditation_user_settings_store.dart';
import '../model/screen_wakelock.dart';
import '../model/wearable_connection.dart';
import 'pages/drawer_page.dart';
import 'pages/meditation_page.dart';
import 'pages/profile_page.dart';
import 'pages/preferences_page.dart';
import 'pages/weekly_analytics_page.dart';
import 'pages/api_keys_page.dart';
import 'pages/privacy_data_page.dart';

class MeditationView extends StatefulWidget {
  final Sensor ppgSensor;
  final Sensor accelerometerSensor;
  final Sensor gyroscopeSensor;
  final SensorConfigurationProvider sensorConfigProvider;
  final Wearable? wearable;
  final MeditationServiceSettingsStore? serviceSettingsStore;
  final MeditationUserSettingsStore? userSettingsStore;

  const MeditationView({
    super.key,
    required this.ppgSensor,
    required this.accelerometerSensor,
    required this.gyroscopeSensor,
    required this.sensorConfigProvider,
    this.wearable,
    this.serviceSettingsStore,
    this.userSettingsStore,
  });

  @override
  State<MeditationView> createState() => _MeditationViewState();
}

class _MeditationViewState extends State<MeditationView> {
  int _selectedIndex = 0;
  MeditationMode? _selectedMode;
  late final UserAccount _userAccount;
  late final MeditationServiceSettingsStore _serviceSettingsStore;
  late final MeditationUserSettingsStore _userSettingsStore;
  late final MeditationAnalyticsStore _analyticsStore;
  late final WearableConnection _wearableConnection;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _userAccount = UserAccount();
    _serviceSettingsStore =
        widget.serviceSettingsStore ?? MeditationServiceSettingsStore();
    _userSettingsStore =
        widget.userSettingsStore ?? MeditationUserSettingsStore();
    _analyticsStore = MeditationAnalyticsStore()..load();
    _wearableConnection = WearableConnection(widget.wearable);
    unawaited(_loadSettings());
    // A session waits minutes on DeepSeek and text-to-speech with no touch
    // input; Android suspends those requests once the screen turns off.
    unawaited(ScreenWakelock.acquire());
  }

  Future<void> _loadSettings() async {
    await _serviceSettingsStore.loadInto(_userAccount);
    await _userSettingsStore.loadInto(_userAccount);
    if (mounted) setState(() => _settingsLoaded = true);
  }

  Future<void> _saveProfileSettings() => _userSettingsStore.save(_userAccount);

  Future<void> _saveMeditationPreferences() async {
    await Future.wait<void>([
      _userSettingsStore.save(_userAccount),
      _serviceSettingsStore.save(_userAccount),
    ]);
  }

  Future<void> _setCloudProcessingConsent(bool enabled) async {
    final previous = _userAccount.cloudProcessingConsent;
    _userAccount.cloudProcessingConsent = enabled;
    try {
      await _userSettingsStore.save(_userAccount);
    } catch (_) {
      _userAccount.cloudProcessingConsent = previous;
      rethrow;
    }
    if (mounted) setState(() {});
  }

  Future<void> _deleteAllMeditationData() async {
    await _userSettingsStore.clear();
    await _serviceSettingsStore.clear(_userAccount);
    await _analyticsStore.clear();
    MeditationUserSettingsStore.clearAccount(_userAccount);
    if (mounted) {
      setState(() {
        _selectedIndex = 0;
        _selectedMode = null;
      });
    }
  }

  List<DrawerPage> get _pages => [
        MeditationPage(
          ppgSensor: widget.ppgSensor,
          accelerometerSensor: widget.accelerometerSensor,
          gyroscopeSensor: widget.gyroscopeSensor,
          sensorConfigProvider: widget.sensorConfigProvider,
          userAccount: _userAccount,
          analyticsStore: _analyticsStore,
          wearable: widget.wearable,
          wearableConnection: _wearableConnection,
          selectedMode: _selectedMode,
          onModeSelected: (mode) => setState(() => _selectedMode = mode),
        ),
        ProfilePage(
          userAccount: _userAccount,
          onSaved: _saveProfileSettings,
        ),
        PreferencesPage(
          userAccount: _userAccount,
          onSaved: _saveMeditationPreferences,
        ),
        WeeklyAnalyticsPage(analyticsStore: _analyticsStore),
        ApiKeysPage(
          userAccount: _userAccount,
          settingsStore: _serviceSettingsStore,
        ),
        PrivacyDataPage(
          userAccount: _userAccount,
          onCloudChoice: _setCloudProcessingConsent,
          onDeleteAll: _deleteAllMeditationData,
        ),
      ];

  @override
  void dispose() {
    unawaited(ScreenWakelock.release());
    _analyticsStore.dispose();
    _wearableConnection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_userAccount.cloudProcessingConsent == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('EarStreAM privacy')),
        body: SafeArea(
          child: PrivacyDataPage(
            userAccount: _userAccount,
            requireChoice: true,
            onCloudChoice: _setCloudProcessingConsent,
            onDeleteAll: _deleteAllMeditationData,
          ),
        ),
      );
    }

    final pages = _pages;

    return Scaffold(
      appBar: AppBar(
        title: const Text("EarStreAM"),
      ),
      endDrawer: SafeArea(
        child: NavigationDrawer(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              if (index == 0) {
                // Always land back on the mode picker, even if the meditation
                // page was already the selected one. Clearing this also
                // unmounts the running mode view, disposing its measurement.
                _selectedMode = null;
              }
              _selectedIndex = index;
            });
            // Close the drawer after selecting a destination
            Navigator.of(context).pop();
          },
          header: DrawerHeader(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'lib/apps/meditation_app/assets/earstream_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                Text(
                  'EarStreAM',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stress-adaptive meditation sessions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          children: pages.map((DrawerPage page) {
            return NavigationDrawerDestination(
              icon: Icon(page.icon),
              label: Text(page.label),
              selectedIcon: Icon(page.selectedIcon),
            );
          }).toList(),
        ),
      ),
      body: SafeArea(child: pages[_selectedIndex]),
    );
  }
}
