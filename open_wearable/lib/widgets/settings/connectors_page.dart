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
  static final Uri _lslGuideUri = Uri.parse(
    'https://github.com/OpenEarable/open_earable_flutter/blob/main/doc/LSL.md',
  );

  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _streamPrefixController;

  bool _enabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _validationMessage;

  final bool _isLslSupported = LslForwarder.instance.isSupported;

  bool get _controlsEnabled => !_isSaving && _isLslSupported;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController(
      text: defaultLslBridgePort.toString(),
    );
    _streamPrefixController = TextEditingController(
      text: defaultLslStreamPrefix,
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
    final settings = await ConnectorSettings.loadLslSettings();
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
  }

  Future<void> _saveSettings() async {
    if (_isSaving) {
      return;
    }

    final host = _hostController.text.trim();
    final parsedPort = int.tryParse(_portController.text.trim());
    final streamPrefix = _streamPrefixController.text.trim().isEmpty
        ? defaultLslStreamPrefix
        : _streamPrefixController.text.trim();

    if (_enabled && host.isEmpty) {
      setState(() {
        _validationMessage = 'Bridge host is required when LSL is enabled.';
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
      final saved = await ConnectorSettings.saveLslSettings(
        LslConnectorSettings(
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
        message: 'LSL connector settings saved.',
        type: AppToastType.success,
        icon: Icons.check_circle_outline_rounded,
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
    if (_isSaving || !_isLslSupported) {
      return;
    }

    final host = _hostController.text.trim();
    final parsedPort = int.tryParse(_portController.text.trim());
    final streamPrefix = _streamPrefixController.text.trim().isEmpty
        ? defaultLslStreamPrefix
        : _streamPrefixController.text.trim();

    if (value && host.isEmpty) {
      setState(() {
        _validationMessage = 'Bridge host is required when LSL is enabled.';
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
      final saved = await ConnectorSettings.saveLslSettings(
        LslConnectorSettings(
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

  void _clearValidationMessage() {
    if (_validationMessage == null) {
      return;
    }
    setState(() {
      _validationMessage = null;
    });
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                Text(
                  'Available connectors',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use connectors to forward wearable data to other platforms, such as software running on your computer (e.g., LSL).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                _buildLslConnectorCard(context),
                const SizedBox(height: 8),
                Text(
                  'More connector integrations will appear here over time.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
    );
  }

  Widget _buildLslConnectorCard(BuildContext context) {
    const lslGreen = Color(0xFF2E7D32);
    final colorScheme = Theme.of(context).colorScheme;
    final isLslActive = _enabled && _hostController.text.trim().isNotEmpty;
    final lslIconColor = isLslActive ? lslGreen : colorScheme.primary;
    final lslIconBackground = lslIconColor.withValues(alpha: 0.12);

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
                    color: lslIconBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.wifi_tethering,
                    color: lslIconColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LSL (Lab Streaming Layer)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Forward sensor data from this app to an LSL bridge on your computer.',
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
                  onChanged: !_controlsEnabled ? null : _setEnabled,
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openExternalUrl(
                  uri: _lslGuideUri,
                  label: 'LSL setup guide',
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open LSL Setup Instructions'),
              ),
            ),
            if (!_isLslSupported) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'LSL forwarding transport is not supported on this platform.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              onChanged: (_) => _clearValidationMessage(),
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
                    onChanged: (_) => _clearValidationMessage(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'UDP Port',
                      hintText: '16571',
                      suffixIcon: IconButton(
                        tooltip: 'Reset to default',
                        onPressed: !_controlsEnabled
                            ? null
                            : () {
                                _portController.text =
                                    defaultLslBridgePort.toString();
                                _clearValidationMessage();
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
                    onChanged: (_) => _clearValidationMessage(),
                    decoration: const InputDecoration(
                      labelText: 'Stream Prefix',
                      hintText: defaultLslStreamPrefix,
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
                onPressed: !_controlsEnabled ? null : _saveSettings,
                child: Text(_isSaving ? 'Saving...' : 'Save & Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
