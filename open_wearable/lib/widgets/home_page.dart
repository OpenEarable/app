import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_wearable/apps/widgets/apps_page.dart';
import 'package:open_wearable/widgets/devices/devices_page.dart';
import 'package:open_wearable/widgets/home_page_overview.dart';
import 'package:open_wearable/widgets/settings/settings_page.dart';

import 'sensors/sensor_page.dart';

const int _overviewIndex = 0;
const int _devicesIndex = 1;
const int _sensorsIndex = 2;
const int _sectionCount = 5;

const double _largeScreenBreakpoint = 960;

class HomePage extends StatefulWidget {
  final int initialSectionIndex;

  const HomePage({super.key, this.initialSectionIndex = _overviewIndex});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PlatformTabController _tabController;
  late final SensorPageController _sensorPageController;
  late final List<_HomeDestination> _destinations;
  late final List<Widget> _sections;
  int _selectedIndex = _overviewIndex;

  @override
  void initState() {
    super.initState();

    final requestedInitial = widget.initialSectionIndex;
    final initialIndex =
        (requestedInitial >= _overviewIndex && requestedInitial < _sectionCount)
            ? requestedInitial
            : _overviewIndex;
    _selectedIndex = initialIndex;

    _tabController = PlatformTabController(initialIndex: initialIndex);
    _sensorPageController = SensorPageController();
    _tabController.addListener(_syncSelectedIndex);

    _destinations = const [
      _HomeDestination(
        title: 'Overview',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _HomeDestination(
        title: 'Devices',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      _HomeDestination(
        title: 'Sensors',
        icon: Icons.ssid_chart_outlined,
        selectedIcon: Icons.ssid_chart,
      ),
      _HomeDestination(
        title: 'Apps',
        icon: Icons.apps_outlined,
        selectedIcon: Icons.apps,
      ),
      _HomeDestination(
        title: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];

    _sections = [
      OverviewPage(
        onDeviceSectionRequested: () => _jumpToSection(_devicesIndex),
        onConnectRequested: _openConnectDevices,
        onSensorTabRequested: _openSensorsTab,
      ),
      const DevicesPage(),
      SensorPage(controller: _sensorPageController),
      const AppsPage(),
      SettingsPage(
        onLogsRequested: _openLogFiles,
        onConnectRequested: _openConnectDevices,
        onGeneralSettingsRequested: _openGeneralSettings,
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.removeListener(_syncSelectedIndex);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _largeScreenBreakpoint) {
          return _buildLargeScreenLayout(context);
        }
        return _buildCompactLayout(context);
      },
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return PlatformTabScaffold(
      tabController: _tabController,
      items: _destinations
          .map(
            (destination) => BottomNavigationBarItem(
              icon: Icon(destination.icon),
              activeIcon: Icon(destination.selectedIcon),
              label: destination.title,
            ),
          )
          .toList(),
      bodyBuilder: (context, index) => IndexedStack(
        index: index,
        children: _sections,
      ),
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context) {
    final bool useExtendedRail = MediaQuery.of(context).size.width >= 1280;

    return PlatformScaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => _selectSection(context, index),
              labelType: NavigationRailLabelType.all,
              extended: useExtendedRail,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: useExtendedRail
                    ? Text(
                        'OpenWearable',
                        style: Theme.of(context).textTheme.titleMedium,
                      )
                    : Icon(
                        Icons.watch,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
              destinations: _destinations
                  .map(
                    (destination) => NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.title),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _sections,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncSelectedIndex() {
    if (!mounted) return;
    final int controllerIndex = _tabController.index(context);
    if (_selectedIndex != controllerIndex) {
      setState(() {
        _selectedIndex = controllerIndex;
      });
    }
  }

  void _jumpToSection(int index) {
    if (!mounted) return;
    _selectSection(context, index);
  }

  void _selectSection(BuildContext context, int index) {
    if (index < 0 || index >= _sections.length) return;

    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
    _tabController.setIndex(context, index);
  }

  void _openConnectDevices() {
    if (!mounted) return;
    context.push('/connect-devices');
  }

  void _openSensorsTab(int tabIndex) {
    if (!mounted) return;
    _selectSection(context, _sensorsIndex);
    _sensorPageController.openTab(tabIndex);
  }

  void _openLogFiles() {
    if (!mounted) return;
    context.push('/log-files');
  }

  void _openGeneralSettings() {
    if (!mounted) return;
    context.push('/settings/general');
  }
}

class _HomeDestination {
  final String title;
  final IconData icon;
  final IconData selectedIcon;

  const _HomeDestination({
    required this.title,
    required this.icon,
    required this.selectedIcon,
  });
}
