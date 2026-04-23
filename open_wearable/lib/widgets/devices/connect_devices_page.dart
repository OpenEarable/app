import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:universal_ble/universal_ble.dart';
import 'package:open_wearable/models/connect_devices_scan_session.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/this_device_wearable.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_recorder_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/devices_page.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:provider/provider.dart';

import '../../models/logger.dart';
import '../../models/wearable_connector.dart';

/// Page for connecting to devices
///
/// All BLE devices are listed and tapping on it will connect to the device.
/// Connected Wearables are added to the [WearablesProvider].
class ConnectDevicesPage extends StatefulWidget {
  const ConnectDevicesPage({super.key});

  @override
  State<ConnectDevicesPage> createState() => _ConnectDevicesPageState();
}

class _ConnectDevicesPageState extends State<ConnectDevicesPage> {
  final WearableManager _wearableManager = WearableManager();
  final Map<String, bool> _connectingDevices = {};

  late ConnectDevicesScanSnapshot _scanSnapshot;
  late final VoidCallback _scanSnapshotListener;
  DiscoveredDevice? _thisDeviceEntry;

  @override
  void initState() {
    super.initState();
    _scanSnapshot = ConnectDevicesScanSession.snapshot;
    _scanSnapshotListener = () {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanSnapshot = ConnectDevicesScanSession.snapshot;
      });
    };

    ConnectDevicesScanSession.notifier.addListener(_scanSnapshotListener);
    if (!_scanSnapshot.isScanning) {
      unawaited(ConnectDevicesScanSession.startScanning(clearPrevious: true));
    }
    unawaited(_addThisDeviceToDiscovered());
  }

  @override
  Widget build(BuildContext context) {
    final wearablesProvider = context.watch<WearablesProvider>();
    final connectedWearables = wearablesProvider.wearables;
    final connectedDeviceIds =
        connectedWearables.map((wearable) => wearable.deviceId).toSet();
    final connectedGroups = orderWearableGroupsForOverview(
      connectedWearables
          .map(
            (wearable) => WearableDisplayGroup.single(
              wearable: wearable,
            ),
          )
          .toList(),
    );

    final scannedDevices = _scanSnapshot.discoveredDevices
        .where((device) => !connectedDeviceIds.contains(device.id))
        .toList();
    final thisDeviceEntry = _thisDeviceEntry;
    final availableDevices = [
      if (thisDeviceEntry != null &&
          !connectedDeviceIds.contains(thisDeviceEntry.id))
        thisDeviceEntry,
      ...scannedDevices.where((device) => device.id != thisDeviceEntry?.id),
    ];

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Connect Devices'),
        trailingActions: [
          const AppBarRecordingIndicator(),
          PlatformIconButton(
            icon: _scanSnapshot.isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching),
            onPressed: _scanSnapshot.isScanning
                ? null
                : () => ConnectDevicesScanSession.startScanning(
                      clearPrevious: true,
                    ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!_scanSnapshot.isScanning) {
            await ConnectDevicesScanSession.startScanning(clearPrevious: true);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            12,
            10,
            12,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _buildScanStatusCard(
              context,
              connectedCount: connectedWearables.length,
              discoveredCount: availableDevices.length,
            ),
            const SizedBox(height: 12),
            _buildSectionHeader(
              context,
              title: 'Connected',
              count: connectedWearables.length,
            ),
            if (connectedWearables.isEmpty)
              _buildEmptyCard(
                context,
                title: 'No devices connected',
                subtitle: 'Tap a discovered device below to connect.',
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < connectedGroups.length; i++) ...[
                    DeviceRow(
                      group: connectedGroups[i],
                      cardMargin: EdgeInsets.zero,
                    ),
                    if (i < connectedGroups.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            const SizedBox(height: 12),
            _buildSectionHeader(
              context,
              title: 'Available',
              count: availableDevices.length,
            ),
            if (availableDevices.isEmpty)
              _buildEmptyCard(
                context,
                title: _scanSnapshot.isScanning
                    ? 'Scanning for devices...'
                    : 'No devices found yet',
                subtitle: _scanSnapshot.isScanning
                    ? 'Make sure your wearable is turned on and nearby.'
                    : 'Press scan again or pull to refresh.',
              )
            else
              ...availableDevices.map(
                (device) {
                  final isThisDevice = device.id == _thisDeviceEntry?.id;
                  final connect = isThisDevice
                      ? () => _connectToThisDevice(context)
                      : () => _connectToDevice(device, context);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: PlatformListTile(
                      leading: Icon(
                        isThisDevice ? Icons.smartphone : Icons.bluetooth,
                      ),
                      title: PlatformText(_deviceName(device)),
                      subtitle: PlatformText(device.id),
                      trailing: _buildTrailingWidget(
                        device,
                        onConnect: connect,
                      ),
                      onTap: _connectingDevices[device.id] == true
                          ? null
                          : connect,
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),
            PlatformElevatedButton(
              onPressed: _scanSnapshot.isScanning
                  ? null
                  : () => ConnectDevicesScanSession.startScanning(
                        clearPrevious: true,
                      ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_scanSnapshot.isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.bluetooth_searching),
                  const SizedBox(width: 8),
                  Text(_scanSnapshot.isScanning ? 'Scanning...' : 'Scan Again'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanStatusCard(
    BuildContext context, {
    required int connectedCount,
    required int discoveredCount,
  }) {
    final statusText = _scanSnapshot.isScanning
        ? 'Scanning for nearby devices'
        : 'Ready to scan';
    final helperText = _scanSnapshot.lastScanStartedAt == null
        ? 'Use Scan to discover nearby wearables.'
        : 'Last scan: ${_formatScanTime(_scanSnapshot.lastScanStartedAt!)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _scanSnapshot.isScanning
                      ? Icons.radar
                      : Icons.bluetooth_searching,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              helperText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(label: '$connectedCount connected'),
                _StatusPill(label: '$discoveredCount available'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
          _StatusPill(label: '$count'),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildTrailingWidget(
    DiscoveredDevice device, {
    required VoidCallback onConnect,
  }) {
    return SizedBox(
      width: 90,
      child: Align(
        alignment: Alignment.centerRight,
        child: _connectingDevices[device.id] == true
            ? const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : PlatformTextButton(
                onPressed: onConnect,
                child: const Text('Connect'),
              ),
      ),
    );
  }

  String _deviceName(DiscoveredDevice device) {
    final name = device.name.trim();
    if (name.isEmpty) return 'Unnamed device';
    return formatWearableDisplayName(name);
  }

  String _formatScanTime(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed.inSeconds < 10) return 'just now';
    if (elapsed.inMinutes < 1) return '${elapsed.inSeconds}s ago';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    return '${elapsed.inHours}h ago';
  }

  Future<void> _addThisDeviceToDiscovered() async {
    if (_thisDeviceEntry != null) return;
    final profile = await DeviceProfile.fetch();
    if (!mounted) return;

    final thisDevice = DiscoveredDevice(
      id: profile.deviceId,
      name: profile.displayName,
      manufacturerData: Uint8List(0),
      rssi: 0,
      serviceUuids: const [],
    );

    setState(() {
      _thisDeviceEntry = thisDevice;
    });
  }

  Future<void> _connectToThisDevice(BuildContext context) async {
    final device = _thisDeviceEntry;
    if (device == null) return;
    if (_connectingDevices[device.id] == true) return;

    setState(() {
      _connectingDevices[device.id] = true;
    });

    try {
      final wearable = await ThisDeviceWearable.create(
        disconnectNotifier: WearableDisconnectNotifier(),
      );
      if (!context.mounted) return;
      context.read<WearablesProvider>().addWearable(wearable);
      context.read<SensorRecorderProvider>().addWearable(wearable);
    } finally {
      if (context.mounted) {
        setState(() {
          _connectingDevices.remove(device.id);
        });
      }
    }
  }

  Future<void> _connectToDevice(
    DiscoveredDevice device,
    BuildContext context,
  ) async {
    if (_connectingDevices[device.id] == true) return;

    setState(() {
      _connectingDevices[device.id] = true;
    });
    final connector = context.read<WearableConnector>();

    try {
      await connector.connect(device);
      ConnectDevicesScanSession.removeDiscoveredDevice(device.id);
    } catch (e, stackTrace) {
      if (_isAlreadyConnectedError(e, device)) {
        logger.i(
          'Device ${device.id} already connected. Attempting stale-connection recovery.',
        );
        final recovered = await _recoverFromStaleConnectionState(
          device: device,
          connector: connector,
        );
        if (recovered) {
          ConnectDevicesScanSession.removeDiscoveredDevice(device.id);
          return;
        }

        logger.i(
          'Stale-connection recovery failed for ${device.id}. Refreshing connected system devices.',
        );
        await _pullConnectedSystemDevices();
        ConnectDevicesScanSession.removeDiscoveredDevice(device.id);
        return;
      }

      final message = _wearableManager.deviceErrorMessage(e, device.name);
      logger.e(
        'Failed to connect to device: ${device.name}, error: $message\n$stackTrace',
      );
      if (context.mounted) {
        showPlatformDialog(
          context: context,
          builder: (dialogContext) => PlatformAlertDialog(
            title: const Text('Connection Error'),
            content: Text(message),
            actions: [
              PlatformDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _connectingDevices.remove(device.id);
        });
      }
    }
  }

  bool _isAlreadyConnectedError(Object error, DiscoveredDevice device) {
    try {
      final message = _wearableManager.deviceErrorMessage(error, device.name);
      return message.toLowerCase().contains('already connected');
    } catch (_) {
      return error.toString().toLowerCase().contains('already connected');
    }
  }

  Future<void> _pullConnectedSystemDevices() async {
    if (!mounted) {
      return;
    }
    try {
      await context.read<WearableConnector>().connectToSystemDevices();
    } catch (error, stackTrace) {
      logger.w('Failed to pull connected system devices: $error\n$stackTrace');
    }
  }

  Future<bool> _recoverFromStaleConnectionState({
    required DiscoveredDevice device,
    required WearableConnector connector,
  }) async {
    try {
      await UniversalBle.disconnect(device.id);
    } catch (error, stackTrace) {
      logger.d(
        'Low-level disconnect attempt for ${device.id} failed during stale recovery: $error\n$stackTrace',
      );
    }

    if (await _retryConnectorConnect(device: device, connector: connector)) {
      return true;
    }

    try {
      await UniversalBle.connect(device.id);
      await UniversalBle.connectionStream(device.id)
          .firstWhere((isConnected) => isConnected)
          .timeout(Duration(seconds: 2));
    } catch (error, stackTrace) {
      logger.d(
        'Low-level connect probe for ${device.id} did not complete during stale recovery: $error\n$stackTrace',
      );
    } finally {
      try {
        await UniversalBle.disconnect(device.id);
      } catch (error, stackTrace) {
        logger.d(
          'Low-level disconnect probe for ${device.id} failed during stale recovery: $error\n$stackTrace',
        );
      }
    }

    await Future<void>.delayed(Duration(milliseconds: 250));
    return _retryConnectorConnect(device: device, connector: connector);
  }

  Future<bool> _retryConnectorConnect({
    required DiscoveredDevice device,
    required WearableConnector connector,
  }) async {
    try {
      await connector.connect(device);
      return true;
    } catch (error, stackTrace) {
      logger.d(
        'Connector retry for ${device.id} failed during stale recovery: $error\n$stackTrace',
      );
      return false;
    }
  }

  @override
  void dispose() {
    ConnectDevicesScanSession.notifier.removeListener(_scanSnapshotListener);
    super.dispose();
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(
              alpha: 0.65,
            ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
