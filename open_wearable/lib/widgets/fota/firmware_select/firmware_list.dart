import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:provider/provider.dart';

class FirmwareList extends StatefulWidget {
  const FirmwareList({super.key});

  @override
  State<FirmwareList> createState() => _FirmwareListState();
}

class _FirmwareListState extends State<FirmwareList> {
  late Future<List<FirmwareEntry>> _firmwareFuture;
  final _repository = UnifiedFirmwareRepository();
  String? firmwareVersion;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadFirmwares();
    _loadFirmwareVersion();
  }

  void _loadFirmwares() {
    _firmwareFuture = _loadFirmwaresWithFallback();
  }

  Future<List<FirmwareEntry>> _loadFirmwaresWithFallback() async {
    List<FirmwareEntry> stable = const <FirmwareEntry>[];
    List<FirmwareEntry> beta = const <FirmwareEntry>[];
    Object? stableError;
    Object? betaError;

    try {
      stable = await _repository.getStableFirmwares();
    } catch (error) {
      stableError = error;
      // Keep going to allow beta-only fallback when stable fetch fails.
    }

    try {
      beta = await _repository.getBetaFirmwares();
    } catch (error) {
      betaError = error;
      // Beta feed is optional. Ignore failures.
    }

    final combined = <FirmwareEntry>[
      ...stable,
      ...beta,
    ];

    if (stableError != null && betaError != null) {
      throw Exception('Could not fetch firmware list from the internet.');
    }

    return combined;
  }

  Future<void> _refreshFirmwares() async {
    setState(_loadFirmwares);
    try {
      await _firmwareFuture;
    } catch (_) {
      // Error state is handled by FutureBuilder.
    }
  }

  Future<void> _loadFirmwareVersion() async {
    final wearable =
        Provider.of<FirmwareUpdateRequestProvider>(context, listen: false)
            .selectedWearable;
    if (wearable == null || !wearable.hasCapability<DeviceFirmwareVersion>()) {
      return;
    }

    try {
      final version = await wearable
          .requireCapability<DeviceFirmwareVersion>()
          .readDeviceFirmwareVersion();
      if (!mounted) {
        return;
      }
      setState(() {
        firmwareVersion = version;
      });
    } catch (_) {
      // Keep UI usable even when firmware version cannot be read.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Select Firmware'),
        trailingActions: [
          PlatformIconButton(
            onPressed: _onCustomFirmwareSelect,
            icon: const Icon(Icons.upload_file_rounded),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
      body: _body(),
    );
  }

  void _onCustomFirmwareSelect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Custom Firmware'),
        content: const Text(
          'By selecting a custom firmware file, you acknowledge that you are doing so at your own risk. The developers are not responsible for any damage caused.',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PlatformDialogAction(
            child: const Text('Continue'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'bin'],
    );
    if (result == null || !mounted) return;

    final ext = result.files.first.extension;
    final fwType =
        ext == 'zip' ? FirmwareType.multiImage : FirmwareType.singleImage;

    final firstResult = result.files.first;
    final path = firstResult.path;
    if (path == null || path.isEmpty) {
      return;
    }
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final fw = LocalFirmware(
      data: bytes,
      type: fwType,
      name: firstResult.name,
    );

    context.read<FirmwareUpdateRequestProvider>().setFirmware(fw);
    Navigator.pop(context);
  }

  Widget _body() {
    return FutureBuilder<List<FirmwareEntry>>(
      future: _firmwareFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return _emptyState();
          }
          return _listBuilder(entries);
        } else if (snapshot.hasError) {
          return _errorWidget();
        }
        return _loadingState();
      },
    );
  }

  Widget _loadingState() {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loading firmware versions...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Text(
              'No firmware is available right now.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorWidget() {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not fetch firmware list from the internet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please check your internet connection and try again.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _refreshFirmwares,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reload'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _listBuilder(List<FirmwareEntry> entries) {
    final stableEntries = entries.where((e) => e.isStable).toList();
    final betaEntries = entries.where((e) => e.isBeta).toList();
    final latestStable = stableEntries.isNotEmpty ? stableEntries.first : null;
    final orderedEntries = <FirmwareEntry>[
      ...stableEntries,
      ...betaEntries,
    ];
    final latestEntry = latestStable ??
        (orderedEntries.isNotEmpty ? orderedEntries.first : entries.first);
    final currentEntry = _findCurrentEntry(orderedEntries);
    final collapsedEntries = <FirmwareEntry>[
      latestEntry,
      if (currentEntry != null && currentEntry != latestEntry) currentEntry,
    ];
    final visibleEntries = _expanded ? orderedEntries : collapsedEntries;
    final visibleStableEntries =
        visibleEntries.where((e) => e.isStable).toList();
    final visibleBetaEntries = visibleEntries.where((e) => e.isBeta).toList();
    final canToggleExpanded = orderedEntries.length > collapsedEntries.length;

    final firmwareRows = <Widget>[
      ...visibleStableEntries.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: SensorPageSpacing.sectionGap),
          child: _firmwareListItem(entry, latestStable),
        ),
      ),
      if (visibleBetaEntries.isNotEmpty) ...[
        if (visibleStableEntries.isNotEmpty)
          const SizedBox(height: SensorPageSpacing.sectionGap),
        _betaWarningBanner(),
        const SizedBox(height: SensorPageSpacing.sectionGap),
        ...visibleBetaEntries.map(
          (entry) => Padding(
            padding:
                const EdgeInsets.only(bottom: SensorPageSpacing.sectionGap),
            child: _firmwareListItem(entry, latestStable),
          ),
        ),
      ],
    ];

    return ListView(
      padding: SensorPageSpacing.pagePaddingWithBottomInset(context),
      children: [
        _summaryCard(
          totalCount: entries.length,
          stableCount: stableEntries.length,
          betaCount: betaEntries.length,
        ),
        if (firmwareRows.isNotEmpty) ...[
          const SizedBox(height: SensorPageSpacing.sectionGap),
          ...firmwareRows,
        ],
        if (canToggleExpanded || _expanded)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              icon: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
              ),
              label: Text(
                _expanded ? 'Hide Older Versions' : 'Show Older Versions',
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryCard({
    required int totalCount,
    required int stableCount,
    required int betaCount,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final installed = _normalizedDeviceVersion;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    size: 15,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Available Firmware',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetaChip(label: '$totalCount total'),
                _MetaChip(label: '$stableCount stable'),
                if (betaCount > 0) _MetaChip(label: '$betaCount beta'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              installed == null
                  ? 'Current firmware version could not be read from the device.'
                  : 'Current device firmware version: $installed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _betaWarningBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.tertiary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Beta firmware is experimental and is not recommended to be used. Use at your own risk.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _firmwareListItem(
    FirmwareEntry entry,
    FirmwareEntry? latestStable,
  ) {
    final firmware = entry.firmware;
    final isBeta = entry.isBeta;
    final isLatestStable = entry == latestStable;
    final isInstalled = _isInstalledFirmware(firmware);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onFirmwareTap(
          firmware,
          isInstalled: isInstalled,
          isLatest: isLatestStable,
          isBeta: isBeta,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFirmwareLeading(
                isBeta: isBeta,
                isInstalled: isInstalled,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firmware.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version ${firmware.version}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isInstalled)
                          _MetaChip(
                            label: 'Current',
                            tone: _ChipTone.success,
                          ),
                        if (isLatestStable)
                          const _MetaChip(
                            label: 'Latest',
                            tone: _ChipTone.success,
                          ),
                        if (isBeta)
                          const _MetaChip(
                            label: 'Beta',
                            tone: _ChipTone.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFirmwareLeading({
    required bool isBeta,
    required bool isInstalled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isBeta
        ? colorScheme.tertiary
        : isInstalled
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;
    final icon = isBeta
        ? Icons.science_outlined
        : isInstalled
            ? Icons.check_circle_rounded
            : Icons.memory_rounded;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 15,
        color: iconColor,
      ),
    );
  }

  void _onFirmwareTap(
    RemoteFirmware firmware, {
    required bool isInstalled,
    required bool isLatest,
    required bool isBeta,
  }) {
    if (isInstalled) {
      _showInstalledDialog(firmware);
    } else if (isBeta) {
      _showBetaWarningDialog(firmware);
    } else if (!isLatest) {
      _showOldVersionWarningDialog(firmware);
    } else {
      _installFirmware(firmware);
    }
  }

  Future<void> _showInstalledDialog(RemoteFirmware firmware) async {
    final confirmed = await showPlatformDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Firmware Already Installed'),
        content: const Text(
          'This firmware version appears to already be installed. Do you want to install it again?',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PlatformDialogAction(
            child: const Text('Install Anyway'),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _installFirmware(firmware);
    }
  }

  Future<void> _showBetaWarningDialog(RemoteFirmware firmware) async {
    final confirmed = await showPlatformDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Install Beta Firmware?'),
        content: const Text(
          'You are about to install beta firmware from a pull request. '
          'This firmware may be unstable or incomplete. '
          'Proceed at your own risk.',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PlatformDialogAction(
            cupertino: (_, __) =>
                CupertinoDialogActionData(isDestructiveAction: true),
            child: const Text('Install Beta'),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _installFirmware(firmware);
    }
  }

  Future<void> _showOldVersionWarningDialog(RemoteFirmware firmware) async {
    final confirmed = await showPlatformDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Install Older Version?'),
        content: const Text(
          'You are selecting an old firmware version. We recommend installing the newest version.',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PlatformDialogAction(
            child: const Text('Proceed'),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _installFirmware(firmware);
    }
  }

  bool _isInstalledFirmware(RemoteFirmware firmware) {
    final version = _normalizedDeviceVersion;
    if (version == null) {
      return false;
    }
    return firmware.version == version || firmware.version.contains(version);
  }

  FirmwareEntry? _findCurrentEntry(List<FirmwareEntry> orderedEntries) {
    final version = _normalizedDeviceVersion;
    if (version == null) {
      return null;
    }

    for (final entry in orderedEntries) {
      final fwVersion = entry.firmware.version;
      if (fwVersion == version || fwVersion.contains(version)) {
        return entry;
      }
    }
    return null;
  }

  String? get _normalizedDeviceVersion {
    final version = firmwareVersion?.replaceAll('\x00', '').trim();
    if (version == null || version.isEmpty) {
      return null;
    }
    return version;
  }

  void _installFirmware(RemoteFirmware firmware) {
    if (!mounted) {
      return;
    }
    context.read<FirmwareUpdateRequestProvider>().setFirmware(firmware);
    Navigator.pop(context);
  }
}

enum _ChipTone { neutral, primary, success, warning }

class _MetaChip extends StatelessWidget {
  final String label;
  final _ChipTone tone;

  const _MetaChip({
    required this.label,
    this.tone = _ChipTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const successGreen = Color(0xFF2E7D32);
    final (foreground, background, border) = switch (tone) {
      _ChipTone.primary => (
          colorScheme.primary,
          colorScheme.primaryContainer.withValues(alpha: 0.3),
          colorScheme.primary.withValues(alpha: 0.35),
        ),
      _ChipTone.success => (
          successGreen,
          successGreen.withValues(alpha: 0.12),
          successGreen.withValues(alpha: 0.34),
        ),
      _ChipTone.warning => (
          colorScheme.tertiary,
          colorScheme.tertiaryContainer.withValues(alpha: 0.5),
          colorScheme.tertiary.withValues(alpha: 0.45),
        ),
      _ChipTone.neutral => (
          colorScheme.onSurfaceVariant,
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
          colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
