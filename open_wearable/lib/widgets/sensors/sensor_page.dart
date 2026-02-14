import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_view.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_view.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_values_page.dart';
import 'package:provider/provider.dart';

class SensorPageController {
  _SensorPageState? _state;
  int? _pendingTabIndex;

  void _attach(_SensorPageState state) {
    _state = state;
    if (_pendingTabIndex != null) {
      state.openTab(_pendingTabIndex!);
      _pendingTabIndex = null;
    }
  }

  void _detach(_SensorPageState state) {
    if (_state == state) {
      _state = null;
    }
  }

  void openTab(int tabIndex) {
    final attachedState = _state;
    if (attachedState == null) {
      _pendingTabIndex = tabIndex;
      return;
    }
    attachedState.openTab(tabIndex);
  }
}

class SensorPage extends StatefulWidget {
  final SensorPageController? controller;

  const SensorPage({
    super.key,
    this.controller,
  });

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant SensorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _tabController.dispose();
    super.dispose();
  }

  void openTab(int tabIndex) {
    final safeIndex = tabIndex.clamp(0, _tabController.length - 1).toInt();
    if (_tabController.index == safeIndex) return;
    _tabController.animateTo(safeIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WearablesProvider>(
      builder: (context, wearablesProvider, child) {
        final hasConnectedDevices = wearablesProvider.wearables.isNotEmpty;

        return PlatformScaffold(
          body: NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: PlatformText("Sensors"),
                  actions: [
                    const AppBarRecordingIndicator(),
                    PlatformIconButton(
                      icon: Icon(context.platformIcons.bluetooth),
                      onPressed: () {
                        context.push('/connect-devices');
                      },
                    ),
                  ],
                  pinned: true,
                  floating: true,
                  snap: true,
                  forceElevated: innerBoxIsScrolled,
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: [
                      const Tab(text: 'Configure'),
                      const Tab(text: 'Live Data'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const RecordingActivityIndicator(size: 14),
                            const SizedBox(width: 4),
                            PlatformText('Recorder'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
            body: hasConnectedDevices
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      SensorConfigurationView(
                        onSetConfigPressed: () {
                          _tabController.animateTo(1);
                        },
                      ),
                      SensorValuesPage(),
                      LocalRecorderView(),
                    ],
                  )
                : _NoSensorDevicesPromptView(
                    onScanPressed: () => context.push('/connect-devices'),
                  ),
          ),
        );
      },
    );
  }
}

class _NoSensorDevicesPromptView extends StatelessWidget {
  final VoidCallback onScanPressed;

  const _NoSensorDevicesPromptView({required this.onScanPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.bluetooth_searching_rounded,
                size: 28,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'No devices connected',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Scan for devices to start streaming and recording data.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onScanPressed,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Scan for devices'),
            ),
          ],
        ),
      ),
    );
  }
}
