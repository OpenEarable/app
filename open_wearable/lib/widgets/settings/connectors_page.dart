import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/connector_settings.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

class ConnectorsPage extends StatefulWidget {
  const ConnectorsPage({super.key});

  @override
  State<ConnectorsPage> createState() => _ConnectorsPageState();
}

class _ConnectorsPageState extends State<ConnectorsPage> {
  static final Uri _udpBridgeGuideUri = Uri.parse(
    'https://github.com/OpenEarable/open_earable_flutter/blob/main/tools/README.md#quick-setup-from-openwearables-app',
  );

  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _streamPrefixController;

  bool _enabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _validationMessage;

  final bool _isUdpBridgeSupported = UdpBridgeForwarder.instance.isSupported;

  bool get _controlsEnabled => !_isSaving && _isUdpBridgeSupported;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController(
      text: defaultUdpBridgePort.toString(),
    );
    _streamPrefixController = TextEditingController(
      text: defaultUdpBridgeStreamPrefix,
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _streamPrefixController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ConnectorSettings.loadUdpBridgeSettings();
      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = settings.enabled;
        _hostController.text = settings.host;
        _portController.text = settings.port.toString();
        _streamPrefixController.text = settings.streamPrefix;
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
        message: 'Failed to load Network Relay settings.',
        type: AppToastType.error,
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) {
      return;
    }

    final host = _hostController.text.trim();
    final parsedPort = int.tryParse(_portController.text.trim());
    final streamPrefix = _streamPrefixController.text.trim().isEmpty
        ? defaultUdpBridgeStreamPrefix
        : _streamPrefixController.text.trim();

    if (_enabled && host.isEmpty) {
      setState(() {
        _validationMessage =
            'Bridge host is required when Network Relay is enabled.';
      });
      return;
    }
    if (parsedPort == null || parsedPort <= 0 || parsedPort > 65535) {
      setState(() {
        _validationMessage = 'Port must be a number between 1 and 65535.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });

    try {
      final saved = await ConnectorSettings.saveUdpBridgeSettings(
        UdpBridgeConnectorSettings(
          enabled: _enabled,
          host: host,
          port: parsedPort,
          streamPrefix: streamPrefix,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = saved.enabled;
        _hostController.text = saved.host;
        _portController.text = saved.port.toString();
        _streamPrefixController.text = saved.streamPrefix;
      });

      AppToast.show(
        context,
        message: 'Network Relay settings saved.',
        type: AppToastType.success,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _validationMessage =
            'Could not save Network Relay settings. Please try again.';
      });
      AppToast.show(
        context,
        message: 'Failed to save Network Relay settings.',
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

  Future<void> _setEnabled(bool value) async {
    if (_isSaving || !_isUdpBridgeSupported) {
      return;
    }
    final previousEnabled = _enabled;

    final host = _hostController.text.trim();
    final parsedPort = int.tryParse(_portController.text.trim());
    final streamPrefix = _streamPrefixController.text.trim().isEmpty
        ? defaultUdpBridgeStreamPrefix
        : _streamPrefixController.text.trim();

    if (value && host.isEmpty) {
      setState(() {
        _validationMessage =
            'Bridge host is required when Network Relay is enabled.';
      });
      return;
    }
    if (parsedPort == null || parsedPort <= 0 || parsedPort > 65535) {
      setState(() {
        _validationMessage = 'Port must be a number between 1 and 65535.';
      });
      return;
    }

    setState(() {
      _enabled = value;
      _isSaving = true;
      _validationMessage = null;
    });

    try {
      final saved = await ConnectorSettings.saveUdpBridgeSettings(
        UdpBridgeConnectorSettings(
          enabled: value,
          host: host,
          port: parsedPort,
          streamPrefix: streamPrefix,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = saved.enabled;
        _hostController.text = saved.host;
        _portController.text = saved.port.toString();
        _streamPrefixController.text = saved.streamPrefix;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = previousEnabled;
        _validationMessage =
            'Could not update connector status. Please try again.';
      });
      AppToast.show(
        context,
        message: 'Failed to update Network Relay status.',
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

  Future<void> _openExternalUrl({
    required Uri uri,
    required String label,
  }) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) {
      return;
    }

    AppToast.show(
      context,
      message: 'Could not open $label.',
      type: AppToastType.error,
      icon: Icons.link_off_rounded,
    );
  }

  void _handleDraftChanged([String? _]) {
    setState(() {
      _validationMessage = null;
    });
  }

  bool _hasPendingUdpBridgeChanges(UdpBridgeConnectorSettings appliedSettings) {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final parsedPort = int.tryParse(portText);
    final hasPortChanged = parsedPort == null ||
        parsedPort <= 0 ||
        parsedPort > 65535 ||
        parsedPort != appliedSettings.port;
    final streamPrefix = _streamPrefixController.text.trim().isEmpty
        ? defaultUdpBridgeStreamPrefix
        : _streamPrefixController.text.trim();

    return _enabled != appliedSettings.enabled ||
        host != appliedSettings.host ||
        hasPortChanged ||
        streamPrefix != appliedSettings.streamPrefix;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Connectors'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  'Available connectors',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Forward sensor data from this app to other platforms, such as your computer',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                _buildUdpBridgeConnectorCard(context),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'More connectors coming soon',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUdpBridgeConnectorCard(BuildContext context) {
    const udpGreen = Color(0xFF2E7D32);
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<UdpBridgeConnectorSettings>(
      valueListenable: ConnectorSettings.udpBridgeSettingsListenable,
      builder: (context, appliedSettings, _) {
        return ValueListenableBuilder<SensorForwarderConnectionState>(
          valueListenable: ConnectorSettings.udpBridgeConnectionStateListenable,
          builder: (context, connectionState, __) {
            final isAppliedUdpBridgeActive =
                appliedSettings.enabled && appliedSettings.isConfigured;
            final hasPendingChanges =
                _hasPendingUdpBridgeChanges(appliedSettings);
            final hasConnectionProblem = isAppliedUdpBridgeActive &&
                connectionState == SensorForwarderConnectionState.unreachable;
            final udpIconColor = hasConnectionProblem
                ? colorScheme.error
                : isAppliedUdpBridgeActive
                    ? udpGreen
                    : colorScheme.primary;
            final udpIconBackground = udpIconColor.withValues(alpha: 0.12);

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
                            color: udpIconBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            hasConnectionProblem
                                ? Icons.cloud_off_rounded
                                : Icons.cloud_done_rounded,
                            color: udpIconColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Network Relay',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Forward sensor data from this app to your computer',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: _enabled,
                          onChanged: !_controlsEnabled ? null : _setEnabled,
                        ),
                      ],
                    ),
                    if (hasConnectionProblem) ...[
                      const SizedBox(height: 8),
                      _buildUdpBridgeConnectionStatus(
                        context,
                        settings: appliedSettings,
                        hasConnectionProblem: hasConnectionProblem,
                      ),
                    ],
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openExternalUrl(
                          uri: _udpBridgeGuideUri,
                          label: 'Network Relay setup guide',
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label:
                            const Text('Open Network Relay Setup Instructions'),
                      ),
                    ),
                    if (!_isUdpBridgeSupported) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Network Relay forwarding is not supported on this platform',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Bridge settings',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _hostController,
                      enabled: _controlsEnabled,
                      onChanged: _handleDraftChanged,
                      decoration: const InputDecoration(
                        labelText: 'Bridge Host / IP',
                        hintText: '192.168.1.42',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _portController,
                            enabled: _controlsEnabled,
                            onChanged: _handleDraftChanged,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Relay Port',
                              hintText: '16571',
                              suffixIcon: IconButton(
                                tooltip: 'Reset to default',
                                onPressed: !_controlsEnabled
                                    ? null
                                    : () {
                                        _portController.text =
                                            defaultUdpBridgePort.toString();
                                        _handleDraftChanged();
                                      },
                                icon: const Icon(Icons.restart_alt_rounded),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _streamPrefixController,
                            enabled: _controlsEnabled,
                            onChanged: _handleDraftChanged,
                            decoration: const InputDecoration(
                              labelText: 'Source Device Name',
                              hintText: defaultUdpBridgeStreamPrefix,
                            ),
                          ),
                        ),
                      ],
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
                        onPressed: !_controlsEnabled || !hasPendingChanges
                            ? null
                            : _saveSettings,
                        child: Text(_isSaving ? 'Saving...' : 'Save & Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUdpBridgeConnectionStatus(
    BuildContext context, {
    required UdpBridgeConnectorSettings settings,
    required bool hasConnectionProblem,
  }) {
    const udpGreen = Color(0xFF2E7D32);
    final colorScheme = Theme.of(context).colorScheme;
    final endpoint = '${settings.host}:${settings.port}';
    final foreground = hasConnectionProblem ? colorScheme.error : udpGreen;
    final background = foreground.withValues(alpha: 0.12);
    final border = foreground.withValues(alpha: 0.34);
    final title = hasConnectionProblem
        ? 'Network Relay unreachable'
        : 'Network Relay active';
    final detail = hasConnectionProblem
        ? 'Could not reach $endpoint. Check host, port, and network'
        : 'Connected to $endpoint';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasConnectionProblem
                ? Icons.cloud_off_rounded
                : Icons.cloud_done_rounded,
            size: 17,
            color: foreground,
          ),
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
                        fontWeight: FontWeight.w600,
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
