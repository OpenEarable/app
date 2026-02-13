import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_wearable/apps/widgets/apps_page.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/devices_page.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:provider/provider.dart';

import 'sensors/sensor_page.dart';

const int _overviewIndex = 0;
const int _devicesIndex = 1;
const int _sensorsIndex = 2;
const int _appsIndex = 3;

const double _largeScreenBreakpoint = 960;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PlatformTabController _tabController;
  late final List<_HomeDestination> _destinations;
  late final List<Widget> _sections;
  int _selectedIndex = _overviewIndex;

  @override
  void initState() {
    super.initState();

    _tabController = PlatformTabController(initialIndex: _overviewIndex);
    _tabController.addListener(_syncSelectedIndex);

    _destinations = const [
      _HomeDestination(
        title: 'Overview',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      _HomeDestination(
        title: 'Devices',
        icon: Icons.devices_outlined,
        selectedIcon: Icons.devices,
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
        title: 'Utilities',
        icon: Icons.handyman_outlined,
        selectedIcon: Icons.handyman,
      ),
    ];

    _sections = [
      _OverviewPage(
        onSectionRequested: _jumpToSection,
        onConnectRequested: _openConnectDevices,
      ),
      const DevicesPage(),
      const SensorPage(),
      const AppsPage(),
      _IntegrationsPage(
        onLogsRequested: _openLogFiles,
        onConnectRequested: _openConnectDevices,
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

  void _openLogFiles() {
    if (!mounted) return;
    context.push('/log-files');
  }
}

class _OverviewPage extends StatelessWidget {
  final void Function(int index) onSectionRequested;
  final VoidCallback onConnectRequested;

  const _OverviewPage({
    required this.onSectionRequested,
    required this.onConnectRequested,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Overview'),
        trailingActions: [
          const AppBarRecordingIndicator(),
          PlatformIconButton(
            icon: Icon(context.platformIcons.bluetooth),
            onPressed: onConnectRequested,
          ),
        ],
      ),
      body: Consumer<WearablesProvider>(
        builder: (context, wearablesProvider, _) {
          final wearables = wearablesProvider.wearables;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Connected devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (wearables.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('No devices connected'),
                    subtitle: const Text(
                      'Connect a wearable to access sensors and apps.',
                    ),
                    trailing: PlatformTextButton(
                      onPressed: onConnectRequested,
                      child: const Text('Connect'),
                    ),
                  ),
                )
              else
                ...wearables.map(
                  (wearable) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.watch),
                      title: Text(wearable.name),
                      subtitle: Text(wearable.deviceId),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/device-detail', extra: wearable),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Quick actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _QuickActionTile(
                icon: Icons.bluetooth_searching,
                title: 'Connect device',
                subtitle: 'Scan and pair a wearable',
                onTap: onConnectRequested,
              ),
              _QuickActionTile(
                icon: Icons.devices,
                title: 'Manage devices',
                subtitle: 'Open connected devices and hardware controls',
                onTap: () => onSectionRequested(_devicesIndex),
              ),
              _QuickActionTile(
                icon: Icons.tune,
                title: 'Configure sensors',
                subtitle: 'Open sensor configuration and apply settings',
                onTap: () => onSectionRequested(_sensorsIndex),
              ),
              _QuickActionTile(
                icon: Icons.apps,
                title: 'Open apps',
                subtitle: 'Launch tracking apps for connected wearables',
                onTap: () => onSectionRequested(_appsIndex),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IntegrationsPage extends StatelessWidget {
  final VoidCallback onLogsRequested;
  final VoidCallback onConnectRequested;

  const _IntegrationsPage({
    required this.onLogsRequested,
    required this.onConnectRequested,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Utilities'),
        trailingActions: [
          const AppBarRecordingIndicator(),
          PlatformIconButton(
            icon: Icon(context.platformIcons.bluetooth),
            onPressed: onConnectRequested,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _QuickActionTile(
            icon: Icons.hub,
            title: 'Connectors',
            subtitle: 'External connector integrations\n(coming soon)',
            enabled: false,
          ),
          _QuickActionTile(
            icon: Icons.receipt_long,
            title: 'Log files',
            subtitle: 'View, share, and remove diagnostic logs',
            onTap: onLogsRequested,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled ? null : Theme.of(context).disabledColor;
    final textColor = enabled ? null : Theme.of(context).disabledColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: textColor == null ? null : TextStyle(color: textColor),
        ),
        subtitle: Text(
          subtitle,
          style: textColor == null ? null : TextStyle(color: textColor),
        ),
        trailing: enabled
            ? const Icon(Icons.chevron_right)
            : Icon(Icons.schedule, color: iconColor),
        onTap: enabled ? onTap : null,
      ),
    );
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
