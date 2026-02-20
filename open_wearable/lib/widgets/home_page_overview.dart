import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/device_detail/device_detail_page.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:provider/provider.dart';

const double _overviewDevicePillMinHeight = 30;

class OverviewPage extends StatelessWidget {
  final VoidCallback onDeviceSectionRequested;
  final VoidCallback onConnectRequested;
  final void Function(int tabIndex) onSensorTabRequested;

  const OverviewPage({
    super.key,
    required this.onDeviceSectionRequested,
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

  void _openDeviceFromOverview(BuildContext context, Wearable wearable) {
    onDeviceSectionRequested();

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

  const _OverviewWorkflowIntroCard({
    required this.onConnectRequested,
    required this.onSensorTabRequested,
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
        ? OverviewPage.formatRecordingTime(recordingStart)
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
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: _overviewDevicePillMinHeight,
          ),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
          ),
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
