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

  @override
  void initState() {
    super.initState();
    _loadFirmwares();
  }

  void _loadFirmwares() {
    _firmwareFuture = repository.getFirmwareImages();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Firmware List'),
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
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final firmware = apps[index];
        final isLatest = index == 0;

        return ListTile(
          title: Text(
            firmware.name,
            style: TextStyle(
              color: isLatest ? Colors.black : Colors.grey,
            ),
          ),
          onTap: () {
            if (!isLatest) {
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
              final selectedFW = apps[index];
              context
                  .read<FirmwareUpdateRequestProvider>()
                  .setFirmware(selectedFW);
              Navigator.pop(context, 'Firmware $index');
            }
          },
        );
      },
    );
  }
}
