import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/widgets/apps_page.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/devices_page.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:provider/provider.dart';

import 'sensors/sensor_page.dart';

const int _overviewIndex = 0;
const int _sensorsIndex = 2;

const double _largeScreenBreakpoint = 960;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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

    _tabController = PlatformTabController(initialIndex: _overviewIndex);
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
        title: 'Utilities',
        icon: Icons.handyman_outlined,
        selectedIcon: Icons.handyman,
      ),
    ];

    _sections = [
      _OverviewPage(
        onSectionRequested: _jumpToSection,
        onConnectRequested: _openConnectDevices,
        onSensorTabRequested: _openSensorsTab,
      ),
      const DevicesPage(),
      SensorPage(controller: _sensorPageController),
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

  void _openSensorsTab(int tabIndex) {
    if (!mounted) return;
    _selectSection(context, _sensorsIndex);
    _sensorPageController.openTab(tabIndex);
  }

  void _openLogFiles() {
    if (!mounted) return;
    context.push('/log-files');
  }
}

class _OverviewPage extends StatelessWidget {
  final void Function(int index) onSectionRequested;
  final VoidCallback onConnectRequested;
  final void Function(int tabIndex) onSensorTabRequested;

  const _OverviewPage({
    required this.onSectionRequested,
    required this.onConnectRequested,
    required this.onSensorTabRequested,
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
      body: Consumer2<WearablesProvider, SensorRecorderProvider>(
        builder: (context, wearablesProvider, recorderProvider, _) {
          final wearables = wearablesProvider.wearables;
          final connectedCount = wearables.length;
          final isRecording = recorderProvider.isRecording;
          final hasSensorStreams = recorderProvider.hasSensorsConnected;
          final recordingStart = recorderProvider.recordingStart;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OverviewHeroCard(
                wearables: wearables,
                connectedCount: connectedCount,
                isRecording: isRecording,
                hasSensorStreams: hasSensorStreams,
                recordingStart: recordingStart,
              ),
              const SizedBox(height: 12),
              _OverviewWorkflowIntroCard(
                onConnectRequested: onConnectRequested,
                onSensorTabRequested: onSensorTabRequested,
              ),
            ],
          );
        },
      ),
    );
  }

  static String formatRecordingTime(DateTime? time) {
    if (time == null) return 'Recording active';
    final local = time.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return 'Recording since ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _OverviewWorkflowIntroCard extends StatelessWidget {
  final VoidCallback onConnectRequested;
  final void Function(int tabIndex) onSensorTabRequested;

  const _OverviewWorkflowIntroCard({
    required this.onConnectRequested,
    required this.onSensorTabRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How the OpenWearables App Works',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Typical workflow: connect devices, configure sensors, validate signal quality, then record.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _OverviewWorkflowStep(
              icon: Icons.bluetooth_connected,
              title: 'Connect devices',
              detail: 'Pair wearables and confirm connection.',
              sectionLabel: 'Devices › Connect',
              isLast: false,
              onTap: onConnectRequested,
            ),
            _OverviewWorkflowStep(
              icon: Icons.tune_outlined,
              title: 'Configure sensors',
              detail: 'Set required channels and sampling.',
              sectionLabel: 'Sensors › Configure',
              isLast: false,
              onTap: () => onSensorTabRequested(0),
            ),
            _OverviewWorkflowStep(
              icon: Icons.ssid_chart_outlined,
              title: 'View sensor data',
              detail: 'Check live signal quality before capture.',
              sectionLabel: 'Sensors › Live Data',
              isLast: false,
              onTap: () => onSensorTabRequested(1),
            ),
            _OverviewWorkflowStep(
              icon: Icons.fiber_smart_record,
              title: 'Record',
              detail: 'Start and monitor recording.',
              sectionLabel: 'Sensors › Recorder',
              isLast: true,
              onTap: () => onSensorTabRequested(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewWorkflowStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String sectionLabel;
  final bool isLast;
  final VoidCallback onTap;

  const _OverviewWorkflowStep({
    required this.icon,
    required this.title,
    required this.detail,
    required this.sectionLabel,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final markerFill = colorScheme.surfaceContainerHighest;
    final markerBorder = colorScheme.outlineVariant.withValues(alpha: 0.7);
    final timelineColor = colorScheme.outlineVariant.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    height: 24,
                    width: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: markerFill,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: markerBorder),
                    ),
                    child: Icon(
                      icon,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: timelineColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                detail,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sectionLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewHeroCard extends StatelessWidget {
  final List<Wearable> wearables;
  final int connectedCount;
  final bool isRecording;
  final bool hasSensorStreams;
  final DateTime? recordingStart;

  const _OverviewHeroCard({
    required this.wearables,
    required this.connectedCount,
    required this.isRecording,
    required this.hasSensorStreams,
    required this.recordingStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReady = connectedCount > 0 && hasSensorStreams && !isRecording;

    final statusLabel = isRecording
        ? 'RECORDING'
        : isReady
            ? 'READY'
            : connectedCount == 0
                ? 'DISCONNECTED'
                : 'SETUP';
    final statusColor = isRecording
        ? colorScheme.error
        : isReady
            ? const Color(0xFF2E7D32)
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.95);
    final statusBackground = statusColor.withValues(alpha: 0.15);
    final statusBorder = statusColor.withValues(alpha: 0.35);

    final title = isRecording
        ? 'Recording in progress'
        : isReady
            ? 'Ready for capture'
            : connectedCount == 0
                ? 'No devices connected'
                : 'Setup required';
    final subtitle = isRecording
        ? _OverviewPage.formatRecordingTime(recordingStart)
        : isReady
            ? 'Connected devices are ready. You can start recording.'
            : connectedCount == 0
                ? 'Pair at least one wearable to begin.'
                : 'Configure required sensors in the Sensors tab.';

    final visibleWearables = wearables.take(5).toList(growable: false);
    final hiddenWearablesCount = wearables.length - visibleWearables.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    border: Border.all(color: statusBorder),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connected Devices ($connectedCount)',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (connectedCount == 0)
              Text(
                'No devices connected.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final wearable in visibleWearables)
                    _ConnectedWearablePill.device(wearable: wearable),
                  if (hiddenWearablesCount > 0)
                    _ConnectedWearablePill.summary(
                      summaryLabel: '+$hiddenWearablesCount more',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedWearablePill extends StatefulWidget {
  final Wearable? wearable;
  final String? summaryLabel;

  const _ConnectedWearablePill.device({
    required this.wearable,
  }) : summaryLabel = null;

  const _ConnectedWearablePill.summary({
    required this.summaryLabel,
  }) : wearable = null;

  String get label => wearable?.name ?? summaryLabel ?? '';

  @override
  State<_ConnectedWearablePill> createState() => _ConnectedWearablePillState();
}

class _ConnectedWearablePillState extends State<_ConnectedWearablePill> {
  Future<DevicePosition?>? _positionFuture;

  @override
  void initState() {
    super.initState();
    _positionFuture = _buildPositionFuture(widget.wearable);
  }

  @override
  void didUpdateWidget(covariant _ConnectedWearablePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wearable != widget.wearable) {
      _positionFuture = _buildPositionFuture(widget.wearable);
    }
  }

  Future<DevicePosition?>? _buildPositionFuture(Wearable? wearable) {
    if (wearable == null || !wearable.hasCapability<StereoDevice>()) {
      return null;
    }
    return wearable.requireCapability<StereoDevice>().position;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildPill(String? sideLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (sideLabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  sideLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_positionFuture == null) {
      return buildPill(null);
    }

    return FutureBuilder<DevicePosition?>(
      future: _positionFuture,
      builder: (context, snapshot) {
        final sideLabel = switch (snapshot.data) {
          DevicePosition.left => 'L',
          DevicePosition.right => 'R',
          _ => null,
        };
        return buildPill(sideLabel);
      },
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
