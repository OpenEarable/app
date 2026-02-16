import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/widgets/apps_page.dart';
import 'package:open_wearable/models/connector_settings.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/devices/devices_page.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_page.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sensors/sensor_page.dart';
import 'sensors/sensor_page_spacing.dart';

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
      _OverviewPage(
        onSectionRequested: _jumpToSection,
        onConnectRequested: _openConnectDevices,
        onSensorTabRequested: _openSensorsTab,
        onConnectorsRequested: _openConnectors,
      ),
      const DevicesPage(),
      SensorPage(controller: _sensorPageController),
      const AppsPage(),
      _SettingsPage(
        onLogsRequested: _openLogFiles,
        onConnectRequested: _openConnectDevices,
        onConnectorsRequested: _openConnectors,
        onAppCloseBehaviorRequested: _openAppCloseBehavior,
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

  void _openConnectors() {
    if (!mounted) return;
    context.push('/connectors');
  }

  void _openAppCloseBehavior() {
    if (!mounted) return;
    context.push('/settings/app-close');
  }
}

class _OverviewPage extends StatelessWidget {
  final void Function(int index) onSectionRequested;
  final VoidCallback onConnectRequested;
  final void Function(int tabIndex) onSensorTabRequested;
  final VoidCallback onConnectorsRequested;

  const _OverviewPage({
    required this.onSectionRequested,
    required this.onConnectRequested,
    required this.onSensorTabRequested,
    required this.onConnectorsRequested,
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
            padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
            children: [
              _OverviewHeroCard(
                wearables: wearables,
                connectedCount: connectedCount,
                isRecording: isRecording,
                hasSensorStreams: hasSensorStreams,
                recordingStart: recordingStart,
                onWearableTap: (wearable) =>
                    _openDeviceFromOverview(context, wearable),
              ),
              ValueListenableBuilder<UdpBridgeConnectorSettings>(
                valueListenable: ConnectorSettings.udpBridgeSettingsListenable,
                builder: (context, udpSettings, _) {
                  final isActive =
                      udpSettings.enabled && udpSettings.isConfigured;
                  if (!isActive) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<SensorForwarderConnectionState>(
                    valueListenable:
                        ConnectorSettings.udpBridgeConnectionStateListenable,
                    builder: (context, connectionState, __) {
                      final hasConnectionProblem = connectionState ==
                          SensorForwarderConnectionState.unreachable;
                      return _OverviewUdpSummaryCard(
                        settings: udpSettings,
                        hasConnectionProblem: hasConnectionProblem,
                      );
                    },
                  );
                },
              ),
              _OverviewWorkflowIntroCard(
                onConnectRequested: onConnectRequested,
                onSensorTabRequested: onSensorTabRequested,
                onConnectorsRequested: onConnectorsRequested,
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

  void _openDeviceFromOverview(BuildContext context, Wearable wearable) {
    onSectionRequested(_devicesIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }

      final isLargeScreen = MediaQuery.of(context).size.width > 600;
      if (isLargeScreen) {
        showGeneralDialog(
          context: context,
          pageBuilder: (dialogContext, animation1, animation2) {
            return Center(
              child: SizedBox(
                width: MediaQuery.of(dialogContext).size.width * 0.5,
                height: MediaQuery.of(dialogContext).size.height * 0.5,
                child: DeviceDetailPage(device: wearable),
              ),
            );
          },
        );
        return;
      }
      context.push('/device-detail', extra: wearable);
    });
  }
}

class _OverviewWorkflowIntroCard extends StatelessWidget {
  final VoidCallback onConnectRequested;
  final void Function(int tabIndex) onSensorTabRequested;
  final VoidCallback onConnectorsRequested;

  const _OverviewWorkflowIntroCard({
    required this.onConnectRequested,
    required this.onSensorTabRequested,
    required this.onConnectorsRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
              isLast: false,
              onTap: () => onSensorTabRequested(2),
            ),
            _OverviewWorkflowStep(
              icon: Icons.share_rounded,
              title: 'Configure Network Relay',
              detail: 'Forward sensor data from this app to your computer.',
              sectionLabel: 'Settings › Connectors',
              isLast: true,
              onTap: onConnectorsRequested,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewUdpSummaryCard extends StatelessWidget {
  final UdpBridgeConnectorSettings settings;
  final bool hasConnectionProblem;

  const _OverviewUdpSummaryCard({
    required this.settings,
    required this.hasConnectionProblem,
  });

  @override
  Widget build(BuildContext context) {
    const udpGreen = Color(0xFF2E7D32);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = hasConnectionProblem ? colorScheme.error : udpGreen;
    final detailTextColor =
        hasConnectionProblem ? colorScheme.error : colorScheme.onSurfaceVariant;
    final infoPillBackground = colorScheme.surface;
    final infoPillBorder = colorScheme.outlineVariant.withValues(alpha: 0.6);
    final infoPillForeground = colorScheme.onSurfaceVariant;
    final statusLine = hasConnectionProblem
        ? 'Data forwarding is currently interrupted.'
        : 'Data is forwarded via the network in real time.';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                hasConnectionProblem
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_rounded,
                size: 18,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasConnectionProblem
                        ? 'Network Relay unreachable'
                        : 'Network Relay is active',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hasConnectionProblem ? colorScheme.error : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: detailTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildRelayInfoPill(
                        context,
                        icon: Icons.dns_rounded,
                        label: 'Host ${settings.host}',
                        backgroundColor: infoPillBackground,
                        borderColor: infoPillBorder,
                        foregroundColor: infoPillForeground,
                      ),
                      _buildRelayInfoPill(
                        context,
                        icon: Icons.settings_ethernet_rounded,
                        label: 'Port ${settings.port}',
                        backgroundColor: infoPillBackground,
                        borderColor: infoPillBorder,
                        foregroundColor: infoPillForeground,
                      ),
                    ],
                  ),
                  if (hasConnectionProblem) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Check host and port in Connectors.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelayInfoPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color borderColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
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
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: colorScheme.primary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
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
  final void Function(Wearable wearable) onWearableTap;

  const _OverviewHeroCard({
    required this.wearables,
    required this.connectedCount,
    required this.isRecording,
    required this.hasSensorStreams,
    required this.recordingStart,
    required this.onWearableTap,
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
        : connectedCount > 0
            ? 'You can start streaming and recording data.'
            : 'Pair at least one wearable to begin.';

    final visibleWearables = wearables.take(5).toList(growable: false);
    final hiddenWearablesCount = wearables.length - visibleWearables.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                if (isRecording)
                  const RecordingActivityIndicator(
                    size: 8,
                    showIdleOutline: false,
                    padding: EdgeInsets.zero,
                  )
                else
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
                    _ConnectedWearablePill.device(
                      wearable: wearable,
                      onWearableTap: onWearableTap,
                    ),
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
  final void Function(Wearable wearable)? onWearableTap;

  const _ConnectedWearablePill.device({
    required this.wearable,
    required this.onWearableTap,
  }) : summaryLabel = null;

  const _ConnectedWearablePill.summary({
    required this.summaryLabel,
  })  : wearable = null,
        onWearableTap = null;

  String get label {
    final name = wearable?.name;
    if (name != null) {
      return formatWearableDisplayName(name);
    }
    return summaryLabel ?? '';
  }

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
      final pill = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
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
                    color: colorScheme.primary.withValues(alpha: 0.24),
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

      final wearable = widget.wearable;
      if (wearable == null || widget.onWearableTap == null) {
        return pill;
      }

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => widget.onWearableTap!(wearable),
          child: pill,
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

class _SettingsPage extends StatelessWidget {
  final VoidCallback onLogsRequested;
  final VoidCallback onConnectRequested;
  final VoidCallback onConnectorsRequested;
  final VoidCallback onAppCloseBehaviorRequested;

  const _SettingsPage({
    required this.onLogsRequested,
    required this.onConnectRequested,
    required this.onConnectorsRequested,
    required this.onAppCloseBehaviorRequested,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Settings'),
        trailingActions: [
          const AppBarRecordingIndicator(),
          PlatformIconButton(
            icon: Icon(context.platformIcons.bluetooth),
            onPressed: onConnectRequested,
          ),
        ],
      ),
      body: ListView(
        padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
        children: [
          _QuickActionTile(
            icon: Icons.hub,
            title: 'Connectors',
            subtitle:
                'Forward sensor data from this app to other platforms, such as your computer.',
            onTap: onConnectorsRequested,
          ),
          _QuickActionTile(
            icon: Icons.tune_rounded,
            title: 'General settings',
            subtitle: 'Manage app-wide behavior.',
            onTap: onAppCloseBehaviorRequested,
          ),
          _QuickActionTile(
            icon: Icons.receipt_long,
            title: 'Log files',
            subtitle: 'View, share, and remove diagnostic logs',
            onTap: onLogsRequested,
          ),
          _QuickActionTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'App information, version, and licenses',
            onTap: () => Navigator.push(
              context,
              platformPageRoute(
                context: context,
                builder: (_) => const _AboutPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  static final Uri _repoUri = Uri.parse('https://github.com/OpenEarable/app');
  static final Uri _tecoUri = Uri.parse('https://teco.edu');
  static final Uri _openWearablesUri = Uri.parse('https://openwearables.com');
  static const String _aboutAttribution =
      'The OpenWearables App is developed and maintained by the TECO research group at the Karlsruhe Institute of Technology and OpenWearables GmbH.';

  Future<void> _openExternalUrl(
    BuildContext context, {
    required Uri uri,
    required String label,
  }) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) {
      return;
    }

    AppToast.show(
      context,
      message: 'Could not open $label.',
      type: AppToastType.error,
      icon: Icons.link_off_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'OpenWearables App',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _aboutAttribution,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'Made with'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            child: Icon(
                              Icons.favorite,
                              size: 15,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const TextSpan(text: 'in Karlsruhe, Germany.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AboutExternalLink(
                        icon: Icons.code_rounded,
                        title: 'Source Code',
                        urlText: 'github.com/OpenEarable/app',
                        onTap: () => _openExternalUrl(
                          context,
                          uri: _repoUri,
                          label: 'GitHub repository',
                        ),
                      ),
                      const SizedBox(height: 6),
                      _AboutExternalLink(
                        icon: Icons.school_outlined,
                        title: 'TECO Research Group',
                        urlText: 'teco.edu',
                        onTap: () => _openExternalUrl(
                          context,
                          uri: _tecoUri,
                          label: 'teco.edu',
                        ),
                      ),
                      const SizedBox(height: 6),
                      _AboutExternalLink(
                        icon: Icons.language_rounded,
                        title: 'OpenWearables GmbH',
                        urlText: 'openwearables.com',
                        trailing: const _OpenWearablesFloatingBadge(),
                        onTap: () => _openExternalUrl(
                          context,
                          uri: _openWearablesUri,
                          label: 'openwearables.com',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Privacy & Data Protection',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Designed for transparency and control.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _PrivacyChecklistItem(
                    text: 'Only data required for app features is processed.',
                  ),
                  const SizedBox(height: 8),
                  const _PrivacyChecklistItem(
                    text: 'Recorded data stays on your device by default.',
                  ),
                  const SizedBox(height: 8),
                  const _PrivacyChecklistItem(
                    text:
                        'Export and sharing happen only when you explicitly choose it.',
                  ),
                  const SizedBox(height: 8),
                  const _PrivacyChecklistItem(
                    text:
                        'Diagnostic logs are shared only through manual user action.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Open source licenses'),
              subtitle: const Text('View third-party software licenses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                platformPageRoute(
                  context: context,
                  builder: (_) => const _OpenSourceLicensesPage(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenSourceLicensesPage extends StatefulWidget {
  const _OpenSourceLicensesPage();

  @override
  State<_OpenSourceLicensesPage> createState() =>
      _OpenSourceLicensesPageState();
}

class _OpenSourceLicensesPageState extends State<_OpenSourceLicensesPage> {
  late final Future<List<_PackageLicenseEntry>> _licensesFuture =
      _loadLicenses();

  Future<List<_PackageLicenseEntry>> _loadLicenses() async {
    final byPackage = <String, Set<String>>{};

    await for (final entry in LicenseRegistry.licenses) {
      final licenseText = entry.paragraphs.map((p) => p.text).join('\n').trim();
      if (licenseText.isEmpty) {
        continue;
      }

      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => <String>{}).add(licenseText);
      }
    }

    final items = byPackage.entries
        .map(
          (entry) => _PackageLicenseEntry(
            packageName: entry.key,
            licenseTexts: entry.value.toList(growable: false),
          ),
        )
        .toList()
      ..sort(
        (a, b) => a.packageName.toLowerCase().compareTo(
              b.packageName.toLowerCase(),
            ),
      );

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Open source licenses'),
      ),
      body: FutureBuilder<List<_PackageLicenseEntry>>(
        future: _licensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load licenses.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final licenses = snapshot.data ?? const <_PackageLicenseEntry>[];

          return ListView(
            padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why this list exists',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The OpenWearables App uses third-party open source software. '
                        'This list provides the required license notices and '
                        'credits for those dependencies.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (licenses.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Text(
                      'No licenses found.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final item in licenses) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          12,
                        ),
                        shape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                        ),
                        collapsedShape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                        ),
                        title: Text(
                          item.packageName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${item.licenseTexts.length} license text${item.licenseTexts.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        children: [
                          for (var i = 0;
                              i < item.licenseTexts.length;
                              i++) ...[
                            SelectableText(
                              item.licenseTexts[i],
                              style: theme.textTheme.bodySmall,
                            ),
                            if (i < item.licenseTexts.length - 1) ...[
                              const SizedBox(height: 10),
                              Divider(
                                height: 1,
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _PackageLicenseEntry {
  final String packageName;
  final List<String> licenseTexts;

  const _PackageLicenseEntry({
    required this.packageName,
    required this.licenseTexts,
  });
}

class _AboutExternalLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String urlText;
  final Widget? trailing;
  final VoidCallback onTap;

  const _AboutExternalLink({
    required this.icon,
    required this.title,
    required this.urlText,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      urlText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenWearablesFloatingBadge extends StatelessWidget {
  const _OpenWearablesFloatingBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeBorderRadius = BorderRadius.circular(999);
    return ClipRRect(
      borderRadius: badgeBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            5,
            5,
            9,
            5,
          ),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(69, 69, 69, 0.40),
            borderRadius: badgeBorderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF2FB26F),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF5ED394),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'OpenWearables',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: theme.textTheme.labelSmall?.fontSize ?? 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyChecklistItem extends StatelessWidget {
  final String text;

  const _PrivacyChecklistItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const checkColor = Color(0xFF2E7D32);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: checkColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
