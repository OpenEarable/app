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
  late Future<List<RemoteFirmware>> _firmwareFuture;
  final repository = FirmwareImageRepository();
  String? firmwareVersion;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadFirmwares();
    _loadFirmwareVersion();
  }

  void _loadFirmwares() {
    _firmwareFuture = repository.getFirmwareImages();
  }

  void _loadFirmwareVersion() async {
    final wearable =
        Provider.of<FirmwareUpdateRequestProvider>(context, listen: false)
            .selectedWearable;
    if (wearable is DeviceFirmwareVersion) {
      final version =
          await (wearable as DeviceFirmwareVersion).readDeviceFirmwareVersion();
      setState(() {
        firmwareVersion = version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Select Firmware'),
        trailingActions: [
          IconButton(
            onPressed: () => onFirmwareSelect(context),
            icon: Icon(Icons.add),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
      body: Material(
        type: MaterialType.transparency,
        child: _body(),
      ),
    );
  }

  void onFirmwareSelect(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Disclaimer'),
        content: const Text(
          'By selecting a custom firmware file, you acknowledge that you are doing so at your own risk. The developers are not responsible for any damage caused.',
        ),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PlatformDialogAction(
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    // Navigator.pop(context, 'Firmware');
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'bin'],
    );
    if (result == null) {
      return;
    }
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

  Container _body() {
    // ignore: avoid_unnecessary_containers
    return Container(
      alignment: Alignment.center,
      child: FutureBuilder<List<RemoteFirmware>>(
        future: _firmwareFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            List<RemoteFirmware> apps = snapshot.data!;
            return _listBuilder(apps);
          } else if (snapshot.hasError) {
            return Expanded(
              child: Column(
                children: [
                  Text("Could not fetch firmware update, plase try again"),
                  const SizedBox(height: 16),
                  PlatformElevatedButton(
                    onPressed: () {
                      setState(_loadFirmwares);
                    },
                    child: const Text('Reload'),
                  ),
                ],
              ),
            );
          }
          return const CircularProgressIndicator();
        },
      ),
    );
  }

  Widget _listBuilder(List<RemoteFirmware> apps) {
    final visibleApps = _expanded ? apps : [apps.first];

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleApps.length,
          itemBuilder: (context, index) {
            final firmware = visibleApps[index];
            final isLatest = firmware == apps.first;
            final remarks = <String>[];
            bool isInstalled = false;

            if (firmwareVersion != null &&
                firmware.version
                    .contains(firmwareVersion!.replaceAll('\x00', ''))) {
              remarks.add('Current');
              isInstalled = true;
            }

            if (isLatest) {
              remarks.add('Latest');
            }

            return ListTile(
              title: Text(
                firmware.name,
                style: TextStyle(
                  color: isLatest ? Colors.black : Colors.grey,
                ),
              ),
              subtitle: Text(
                remarks.join(', '),
                style: TextStyle(
                  color: isLatest ? Colors.black : Colors.grey,
                ),
              ),
              onTap: () {
                if (isInstalled) {
                  showDialog(
                    context: context,
                    builder: (context) => PlatformAlertDialog(
                      title: const Text('Already Installed'),
                      content: const Text(
                        'This firmware version is already installed on the device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            final selectedFW = apps[index];
                            context
                                .read<FirmwareUpdateRequestProvider>()
                                .setFirmware(selectedFW);
                            Navigator.of(context).pop();
                            Navigator.pop(context, 'Firmware $index');
                          },
                          child: const Text('Install Anyway'),
                        ),
                      ],
                    ),
                  );
                } else if (!isLatest) {
                  showDialog(
                    context: context,
                    builder: (context) => PlatformAlertDialog(
                      title: const Text('Warning'),
                      content: const Text(
                        'You are selecting an old firmware version. We recommend installing the newest version.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            final selectedFW = apps[index];
                            context
                                .read<FirmwareUpdateRequestProvider>()
                                .setFirmware(selectedFW);
                            Navigator.of(context).pop();
                            Navigator.pop(context, 'Firmware $index');
                          },
                          child: const Text('Proceed'),
                        ),
                      ],
                    ),
                  );
                } else {
                  context
                      .read<FirmwareUpdateRequestProvider>()
                      .setFirmware(firmware);
                  Navigator.pop(context, 'Firmware $index');
                }
              },
            );
          },
        ),
        if (apps.length > 1)
          PlatformTextButton(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded ? 'Hide older versions' : 'Show older versions',
                  style: TextStyle(color: Colors.black),
                ),
                SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
          ),
      ],
    );
  }
}
