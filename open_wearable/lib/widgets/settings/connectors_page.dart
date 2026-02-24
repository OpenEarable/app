import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/models/connector_settings.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class ConnectorsPage extends StatefulWidget {
  const ConnectorsPage({super.key});

  @override
  State<ConnectorsPage> createState() => _ConnectorsPageState();
}

class _ConnectorsPageState extends State<ConnectorsPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _pathController;

  bool _enabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _pathController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ConnectorSettings.loadWebSocketSettings();
      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = settings.enabled;
        _hostController.text = settings.host;
        _portController.text = settings.port.toString();
        _pathController.text = settings.path;
        _validationMessage = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _validationMessage = 'Could not load connector settings.';
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
        _hostController.text = saved.host;
        _portController.text = saved.port.toString();
        _pathController.text = saved.path;
      });

      AppToast.show(
        context,
        message: 'WebSocket IPC settings saved.',
        type: AppToastType.success,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _validationMessage =
            'Could not start WebSocket IPC server: ${error.toString()}';
      });
      AppToast.show(
        context,
        message: 'Failed to apply WebSocket IPC settings.',
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
    final host = _hostController.text.trim();
    final parsedPort = int.tryParse(_portController.text.trim());
    final rawPath = _pathController.text.trim();
    final path = rawPath.isEmpty ? '/ws' : rawPath;

    if (host.isEmpty) {
      setState(() {
        _validationMessage = 'Host is required.';
      });
      return null;
    }

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
      host: host,
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
        _hostController.text.trim() != applied.host ||
        parsedPort != applied.port ||
        path != applied.path;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Connectors'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<WebSocketConnectorSettings>(
              valueListenable: ConnectorSettings.webSocketSettingsListenable,
              builder: (context, appliedSettings, _) {
                return ValueListenableBuilder<ConnectorRuntimeStatus>(
                  valueListenable:
                      ConnectorSettings.webSocketRuntimeStatusListenable,
                  builder: (context, runtimeStatus, __) {
                    final pending = _hasPendingChanges(appliedSettings);
                    return ListView(
                      padding:
                          SensorPageSpacing.pagePaddingWithBottomInset(context),
                      children: [
                        Text(
                          'Connectors',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Expose OpenEarable features for external tools.',
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
      ConnectorRuntimeState.running => const Color(0xFF1E6A3A),
      ConnectorRuntimeState.starting => colorScheme.primary,
      ConnectorRuntimeState.error => colorScheme.error,
      ConnectorRuntimeState.disabled => colorScheme.onSurfaceVariant,
    };

    final endpoint = Uri(
      scheme: 'ws',
      host: _hostController.text.trim().isEmpty
          ? appliedSettings.host
          : _hostController.text.trim(),
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
                    Icons.cable_rounded,
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
                        'WebSocket IPC',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Expose the OpenEarable Flutter API over JSON messages.',
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
            TextField(
              controller: _hostController,
              enabled: !_isSaving,
              onChanged: _clearValidation,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: '127.0.0.1',
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
            SizedBox(
              width: double.infinity,
              child: PlatformElevatedButton(
                onPressed:
                    _isSaving || !hasPendingChanges ? null : _saveSettings,
                child: Text(_isSaving ? 'Saving...' : 'Save & Apply'),
              ),
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
      ConnectorRuntimeState.running => (
          'Running',
          endpoint,
          const Color(0xFF1E6A3A),
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
          Icon(Icons.circle, size: 10, color: foreground),
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
