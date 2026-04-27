import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/models/connector_settings.dart';
import 'package:open_wearable/models/network/device_ip_address.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/connector_branding.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class ConnectorsPage extends StatefulWidget {
  const ConnectorsPage({super.key});

  @override
  State<ConnectorsPage> createState() => _ConnectorsPageState();
}

class _ConnectorsPageState extends State<ConnectorsPage> {
  late final TextEditingController _portController;
  late final TextEditingController _pathController;
  late final ValueListenable<ConnectorRuntimeStatus> _runtimeStatusListenable;

  bool _enabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isResolvingIpAddress = true;
  String? _currentIpAddress;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController();
    _pathController = TextEditingController();
    _runtimeStatusListenable =
        ConnectorSettings.webSocketRuntimeStatusListenable;
    _runtimeStatusListenable.addListener(_syncCurrentIpAddress);
    _loadSettings();
  }

  @override
  void dispose() {
    _runtimeStatusListenable.removeListener(_syncCurrentIpAddress);
    _portController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  void _syncCurrentIpAddress() {
    final status = _runtimeStatusListenable.value;
    if (status.state != ConnectorRuntimeState.running) {
      return;
    }
    if (_currentIpAddress == status.reachableNetworkAddress) {
      return;
    }
    setState(() {
      _currentIpAddress = status.reachableNetworkAddress;
    });
  }

  Future<void> _loadSettings() async {
    try {
      final settingsFuture = ConnectorSettings.loadWebSocketSettings();
      final ipAddressFuture = resolveCurrentDeviceIpAddress();
      final settings = await settingsFuture;
      final ipAddress = await ipAddressFuture;
      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = settings.enabled;
        _portController.text = settings.port.toString();
        _pathController.text = settings.path;
        _currentIpAddress = ipAddress;
        _validationMessage = null;
        _isResolvingIpAddress = false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _validationMessage = 'Could not load connector settings.';
        _isResolvingIpAddress = false;
        _isLoading = false;
      });
      AppToast.show(
        context,
        message: 'Failed to load connector settings.',
        type: AppToastType.error,
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _refreshCurrentIpAddress() async {
    setState(() {
      _isResolvingIpAddress = true;
      _validationMessage = null;
    });

    try {
      final ipAddress = await resolveCurrentDeviceIpAddress();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentIpAddress = ipAddress;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentIpAddress = null;
        _validationMessage =
            'Could not determine the current device IP address.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingIpAddress = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) {
      return;
    }

    final validated = _buildValidatedSettings();
    if (validated == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });

    try {
      final saved = await ConnectorSettings.saveWebSocketSettings(validated);
      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = saved.enabled;
        _portController.text = saved.port.toString();
        _pathController.text = saved.path;
      });

      AppToast.show(
        context,
        message: 'Network connector settings saved.',
        type: AppToastType.success,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _validationMessage =
            'Could not start network connector server: ${error.toString()}';
      });
      AppToast.show(
        context,
        message: 'Failed to apply network connector settings.',
        type: AppToastType.error,
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _resetSettingsToDefaults() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });

    try {
      final saved = await ConnectorSettings.saveWebSocketSettings(
        const WebSocketConnectorSettings.defaults(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = saved.enabled;
        _portController.text = saved.port.toString();
        _pathController.text = saved.path;
      });

      AppToast.show(
        context,
        message: 'Network connector settings reset to defaults.',
        type: AppToastType.success,
        icon: Icons.restart_alt_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _validationMessage =
            'Could not restore default network connector settings: ${error.toString()}';
      });
      AppToast.show(
        context,
        message: 'Failed to reset network connector settings.',
        type: AppToastType.error,
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  WebSocketConnectorSettings? _buildValidatedSettings() {
    final parsedPort = int.tryParse(_portController.text.trim());
    final rawPath = _pathController.text.trim();
    final path = rawPath.isEmpty ? '/ws' : rawPath;

    if (parsedPort == null || parsedPort <= 0 || parsedPort > 65535) {
      setState(() {
        _validationMessage = 'Port must be between 1 and 65535.';
      });
      return null;
    }

    if (!path.startsWith('/')) {
      setState(() {
        _validationMessage = 'Path must start with /. Example: /ws';
      });
      return null;
    }

    return WebSocketConnectorSettings(
      enabled: _enabled,
      port: parsedPort,
      path: path,
    );
  }

  void _clearValidation([String? _]) {
    if (_validationMessage == null) {
      return;
    }
    setState(() {
      _validationMessage = null;
    });
  }

  bool _hasPendingChanges(WebSocketConnectorSettings applied) {
    final parsedPort = int.tryParse(_portController.text.trim());
    final path = _pathController.text.trim().isEmpty
        ? '/ws'
        : _pathController.text.trim();

    return _enabled != applied.enabled ||
        parsedPort != applied.port ||
        path != applied.path;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text(ConnectorBranding.pluralLabel),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<WebSocketConnectorSettings>(
              valueListenable: ConnectorSettings.webSocketSettingsListenable,
              builder: (context, appliedSettings, _) {
                return ValueListenableBuilder<ConnectorRuntimeStatus>(
                  valueListenable: _runtimeStatusListenable,
                  builder: (context, runtimeStatus, __) {
                    final pending = _hasPendingChanges(appliedSettings);
                    return ListView(
                      padding:
                          SensorPageSpacing.pagePaddingWithBottomInset(context),
                      children: [
                        Text(
                          ConnectorBranding.pluralLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Expose OpenWearable features for external tools.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        _buildWebSocketConnectorCard(
                          context,
                          appliedSettings: appliedSettings,
                          runtimeStatus: runtimeStatus,
                          hasPendingChanges: pending,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildWebSocketConnectorCard(
    BuildContext context, {
    required WebSocketConnectorSettings appliedSettings,
    required ConnectorRuntimeStatus runtimeStatus,
    required bool hasPendingChanges,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = switch (runtimeStatus.state) {
      ConnectorRuntimeState.running =>
        runtimeStatus.isHealthy ? const Color(0xFF1E6A3A) : colorScheme.error,
      ConnectorRuntimeState.starting => colorScheme.primary,
      ConnectorRuntimeState.error => colorScheme.error,
      ConnectorRuntimeState.disabled => colorScheme.onSurfaceVariant,
    };

    final endpoint = Uri(
      scheme: 'ws',
      host: (_currentIpAddress?.trim().isNotEmpty ?? false)
          ? _currentIpAddress!.trim()
          : 'device-ip-unavailable',
      port: int.tryParse(_portController.text.trim()) ?? appliedSettings.port,
      path: _pathController.text.trim().isEmpty
          ? appliedSettings.path
          : _pathController.text.trim(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    ConnectorBranding.icon,
                    size: 18,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Network Connector',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Expose the OpenWearable Flutter API over JSON messages.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: _enabled,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _enabled = value;
                            _validationMessage = null;
                          });
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Current IP Address',
                suffixIcon: IconButton(
                  onPressed: _isSaving || _isResolvingIpAddress
                      ? null
                      : _refreshCurrentIpAddress,
                  icon: _isResolvingIpAddress
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh IP address',
                ),
              ),
              child: Text(
                _currentIpAddress ?? 'Unavailable on this device',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portController,
                    enabled: !_isSaving,
                    onChanged: _clearValidation,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8765',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    enabled: !_isSaving,
                    onChanged: _clearValidation,
                    decoration: const InputDecoration(
                      labelText: 'Path',
                      hintText: '/ws',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _StatusChip(
              status: runtimeStatus,
              endpoint: endpoint.toString(),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PlatformTextButton(
                    onPressed: _isSaving ? null : _resetSettingsToDefaults,
                    child: const Text('Reset to Defaults'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PlatformElevatedButton(
                    onPressed:
                        _isSaving || !hasPendingChanges ? null : _saveSettings,
                    child: Text(_isSaving ? 'Saving...' : 'Save & Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ConnectorRuntimeStatus status;
  final String endpoint;

  const _StatusChip({
    required this.status,
    required this.endpoint,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (title, detail, foreground) = switch (status.state) {
      ConnectorRuntimeState.running when status.hasReachableNetworkAddress => (
          'Running',
          endpoint,
          const Color(0xFF1E6A3A),
        ),
      ConnectorRuntimeState.running => (
          'Wi-Fi unavailable',
          'Connector is on, but no local network address is available.',
          colorScheme.error,
        ),
      ConnectorRuntimeState.starting => (
          'Starting',
          endpoint,
          colorScheme.primary,
        ),
      ConnectorRuntimeState.error => (
          'Error',
          status.message ?? 'Unknown startup error',
          colorScheme.error,
        ),
      ConnectorRuntimeState.disabled => (
          'Disabled',
          'Connector is off',
          colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(ConnectorBranding.icon, size: 14, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
