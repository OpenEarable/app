import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/view_models/wearables_provider.dart';
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
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  Timer? _scanIndicatorTimer;

  final List<DiscoveredDevice> _discoveredDevices = [];
  final Map<String, bool> _connectingDevices = {};

  bool _isScanning = false;
  DateTime? _lastScanStartedAt;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  Widget build(BuildContext context) {
    final wearablesProvider = context.watch<WearablesProvider>();
    final connectedWearables = wearablesProvider.wearables;
    final connectedDeviceIds =
        connectedWearables.map((wearable) => wearable.deviceId).toSet();

    final availableDevices = _discoveredDevices
        .where((device) => !connectedDeviceIds.contains(device.id))
        .toList()
      ..sort((a, b) {
        final nameCompare = _deviceName(a)
            .toLowerCase()
            .compareTo(_deviceName(b).toLowerCase());
        if (nameCompare != 0) return nameCompare;
        return a.id.compareTo(b.id);
      });

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Connect Devices'),
        trailingActions: [
          PlatformIconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching),
            onPressed:
                _isScanning ? null : () => _startScanning(clearPrevious: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _startScanning(clearPrevious: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
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
              ...connectedWearables.map(
                (wearable) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: PlatformListTile(
                    leading: const Icon(Icons.watch_outlined),
                    title: PlatformText(wearable.name),
                    subtitle: PlatformText(wearable.deviceId),
                    trailing: Icon(
                      PlatformIcons(context).checkMark,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
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
                title: _isScanning
                    ? 'Scanning for devices...'
                    : 'No devices found yet',
                subtitle: _isScanning
                    ? 'Make sure your wearable is turned on and nearby.'
                    : 'Press scan again or pull to refresh.',
              )
            else
              ...availableDevices.map(
                (device) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: PlatformListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: PlatformText(_deviceName(device)),
                    subtitle: PlatformText(device.id),
                    trailing: _buildTrailingWidget(device),
                    onTap: _connectingDevices[device.id] == true
                        ? null
                        : () => _connectToDevice(device, context),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            PlatformElevatedButton(
              onPressed: _isScanning
                  ? null
                  : () => _startScanning(clearPrevious: true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.bluetooth_searching),
                  const SizedBox(width: 8),
                  Text(_isScanning ? 'Scanning...' : 'Scan Again'),
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
    final statusText =
        _isScanning ? 'Scanning for nearby devices' : 'Ready to scan';
    final helperText = _lastScanStartedAt == null
        ? 'Use Scan to discover nearby wearables.'
        : 'Last scan: ${_formatScanTime(_lastScanStartedAt!)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isScanning ? Icons.radar : Icons.bluetooth_searching,
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

  Widget _buildTrailingWidget(DiscoveredDevice device) {
    if (_connectingDevices[device.id] == true) {
      return SizedBox(
        height: 24,
        width: 24,
        child: PlatformCircularProgressIndicator(),
      );
    }
    return PlatformTextButton(
      onPressed: () => _connectToDevice(device, context),
      child: const Text('Connect'),
    );
  }

  String _deviceName(DiscoveredDevice device) {
    final name = device.name.trim();
    if (name.isEmpty) return 'Unnamed device';
    return name;
  }

  String _formatScanTime(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed.inSeconds < 10) return 'just now';
    if (elapsed.inMinutes < 1) return '${elapsed.inSeconds}s ago';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    return '${elapsed.inHours}h ago';
  }

  Future<void> _startScanning({bool clearPrevious = false}) async {
    _scanIndicatorTimer?.cancel();

    if (mounted) {
      setState(() {
        if (clearPrevious) {
          _discoveredDevices.clear();
        }
        _isScanning = true;
        _lastScanStartedAt = DateTime.now();
      });
    }

    await _scanSubscription?.cancel();
    _wearableManager.startScan();
    _scanSubscription = _wearableManager.scanStream.listen(
      (incomingDevice) {
        if (incomingDevice.name.isEmpty) return;

        if (_discoveredDevices
            .any((device) => device.id == incomingDevice.id)) {
          return;
        }

        logger.d('Discovered device: ${incomingDevice.name}');
        if (mounted) {
          setState(() {
            _discoveredDevices.add(incomingDevice);
          });
        }
      },
      onError: (error, stackTrace) {
        logger.w('Device scan stream error: $error\n$stackTrace');
      },
    );

    _scanIndicatorTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  Future<void> _connectToDevice(
    DiscoveredDevice device,
    BuildContext context,
  ) async {
    if (_connectingDevices[device.id] == true) return;

    setState(() {
      _connectingDevices[device.id] = true;
    });

    try {
      final connector = context.read<WearableConnector>();
      await connector.connect(device);
      if (mounted) {
        setState(() {
          _discoveredDevices.removeWhere((d) => d.id == device.id);
        });
      }
    } catch (e) {
      final message = _wearableManager.deviceErrorMessage(e, device.name);
      logger.e('Failed to connect to device: ${device.name}, error: $message');
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

  @override
  void dispose() {
    _scanIndicatorTimer?.cancel();
    _scanSubscription?.cancel();
    _wearableManager.setAutoConnect([]);
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
