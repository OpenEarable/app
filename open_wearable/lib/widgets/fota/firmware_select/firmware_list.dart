// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

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
  bool _showBeta = false;

  @override
  void initState() {
    super.initState();
    _loadFirmwares();
    _loadFirmwareVersion();
  }

  void _loadFirmwares() {
    _firmwareFuture = _repository.getAllFirmwares(includeBeta: _showBeta);
  }

  void _loadFirmwareVersion() async {
    final wearable =
        Provider.of<FirmwareUpdateRequestProvider>(context, listen: false)
            .selectedWearable;
    if (wearable != null && wearable.hasCapability<DeviceFirmwareVersion>()) {
      final version =
          await wearable.requireCapability<DeviceFirmwareVersion>().readDeviceFirmwareVersion();
      setState(() {
        firmwareVersion = version;
      });
    }
  }

  void _toggleBeta() {
    setState(() {
      _showBeta = !_showBeta;
      _loadFirmwares();
    });
    print(_showBeta ? 'Beta firmware enabled' : 'Beta firmware disabled');
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: GestureDetector(
          onLongPress: _toggleBeta,
          child: PlatformText('Select Firmware'),
        ),
        trailingActions: [
          IconButton(
            onPressed: () => _onCustomFirmwareSelect(context),
            icon: Icon(Icons.add),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
      body: _body(), // Remove Material wrapper
    );
  }

  void _onCustomFirmwareSelect(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: PlatformText('Disclaimer'),
        content: PlatformText(
          'By selecting a custom firmware file, you acknowledge that you are doing so at your own risk. The developers are not responsible for any damage caused.',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: PlatformText(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PlatformDialogAction(
            child: PlatformText(
              'Continue',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'bin'],
    );
    if (result == null) return;

    final ext = result.files.first.extension;
    final fwType =
        ext == 'zip' ? FirmwareType.multiImage : FirmwareType.singleImage;

    final firstResult = result.files.first;
    final file = File(firstResult.path!);
    final bytes = await file.readAsBytes();

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
            return Center(child: PlatformText('No firmware available'));
          }
          return _listBuilder(entries);
        } else if (snapshot.hasError) {
          return _errorWidget();
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _errorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlatformText("Could not fetch firmware, please try again"),
          const SizedBox(height: 16),
          PlatformElevatedButton(
            onPressed: _loadFirmwares,
            child: PlatformText('Reload'),
          ),
        ],
      ),
    );
  }

  Widget _listBuilder(List<FirmwareEntry> entries) {
    final stableEntries = entries.where((e) => e.isStable).toList();
    final betaEntries = entries.where((e) => e.isBeta).toList();
    final latestStable = stableEntries.isNotEmpty ? stableEntries.first : null;

    final visibleEntries = _expanded ? entries : [entries.first];

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (_showBeta && betaEntries.isNotEmpty) _betaWarningBanner(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleEntries.length,
              itemBuilder: (context, index) =>
                  _firmwareListItem(visibleEntries[index], latestStable, index),
            ),
            if (entries.length > 1) _expandButton(),
            const SizedBox(height: 16), // Simple bottom padding
          ],
        ),
      ),
    );
  }

  Widget _betaWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.orange.withOpacity(0.2),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: PlatformText(
              'Beta firmware is experimental and may be unstable. Use at your own risk.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _firmwareListItem(
      FirmwareEntry entry, FirmwareEntry? latestStable, int index) {
    final firmware = entry.firmware;
    final isBeta = entry.isBeta;
    final isLatestStable = entry == latestStable;
    final remarks = <String>[];
    bool isInstalled = false;

    if (firmwareVersion != null &&
        firmware.version.contains(firmwareVersion!.replaceAll('\x00', ''))) {
      remarks.add('Current');
      isInstalled = true;
    }

    if (isLatestStable) {
      remarks.add('Latest');
    }

    if (isBeta) {
      remarks.add('Beta');
    }

    return ListTile(
      leading: isBeta ? Icon(Icons.bug_report, color: Colors.orange) : null,
      title: PlatformText(
        firmware.name,
        style: TextStyle(
          color: isLatestStable ? Colors.black : Colors.grey,
        ),
      ),
      subtitle: PlatformText(
        remarks.join(', '),
        style: TextStyle(
          color: isLatestStable ? Colors.black : Colors.grey,
        ),
      ),
      onTap: () => _onFirmwareTap(
        firmware,
        index,
        isInstalled,
        isLatestStable,
        isBeta,
      ),
    );
  }

  Widget _expandButton() {
    return PlatformTextButton(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlatformText(
            _expanded ? 'Hide older versions' : 'Show older versions',
            style: TextStyle(color: Colors.black),
          ),
          SizedBox(width: 8),
          Icon(
            _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          ),
        ],
      ),
      onPressed: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
    );
  }

  void _onFirmwareTap(
    RemoteFirmware firmware,
    int index,
    bool isInstalled,
    bool isLatest,
    bool isBeta,
  ) {
    if (isInstalled) {
      _showInstalledDialog(firmware, index);
    } else if (isBeta) {
      _showBetaWarningDialog(firmware, index);
    } else if (!isLatest) {
      _showOldVersionWarningDialog(firmware, index);
    } else {
      _installFirmware(firmware, index);
    }
  }

  void _showInstalledDialog(RemoteFirmware firmware, int index) {
    showDialog(
      context: context,
      builder: (context) => PlatformAlertDialog(
        title: PlatformText('Already Installed'),
        content: PlatformText(
          'This firmware version is already installed on the device.',
        ),
        actions: [
          PlatformTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: PlatformText('Cancel'),
          ),
          PlatformTextButton(
            onPressed: () {
              _installFirmware(firmware, index);
              Navigator.of(context).pop();
            },
            child: PlatformText('Install Anyway'),
          ),
        ],
      ),
    );
  }

  void _showBetaWarningDialog(RemoteFirmware firmware, int index) {
    showDialog(
      context: context,
      builder: (context) => PlatformAlertDialog(
        title: PlatformText('Beta Firmware Warning'),
        content: PlatformText(
          'You are about to install beta firmware from a pull request. '
          'This firmware may be unstable or incomplete. '
          'Proceed at your own risk.',
        ),
        actions: [
          PlatformTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: PlatformText('Cancel'),
          ),
          PlatformTextButton(
            onPressed: () {
              _installFirmware(firmware, index);
              Navigator.of(context).pop();
            },
            child: PlatformText(
              'Install',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showOldVersionWarningDialog(RemoteFirmware firmware, int index) {
    showDialog(
      context: context,
      builder: (context) => PlatformAlertDialog(
        title: PlatformText('Warning'),
        content: PlatformText(
          'You are selecting an old firmware version. We recommend installing the newest version.',
        ),
        actions: [
          PlatformTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: PlatformText('Cancel'),
          ),
          PlatformTextButton(
            onPressed: () {
              _installFirmware(firmware, index);
              Navigator.of(context).pop();
            },
            child: PlatformText('Proceed'),
          ),
        ],
      ),
    );
  }

  void _installFirmware(RemoteFirmware firmware, int index) {
    context.read<FirmwareUpdateRequestProvider>().setFirmware(firmware);
    Navigator.pop(context, 'Firmware $index');
  }
}
