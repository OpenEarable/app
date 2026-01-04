// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BetaFirmwareList extends StatefulWidget {
  const BetaFirmwareList({super.key});

  @override
  State<BetaFirmwareList> createState() => _BetaFirmwareListState();
}

class _BetaFirmwareListState extends State<BetaFirmwareList> {
  late Future<List<RemoteFirmware>> _firmwareFuture;
  String? firmwareVersion;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadFirmwares();
    _loadFirmwareVersion();
  }

  void _loadFirmwares() {
    _firmwareFuture = _fetchLatestFotaPerPR();
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

  Future<List<RemoteFirmware>> _fetchLatestFotaPerPR() async {
    const owner = 'OpenEarable';
    const repo = 'open-earable-2';

    // Fetch artifacts
    final artifactsResponse = await http.get(
      Uri.parse(
        'https://api.github.com/repos/$owner/$repo/actions/artifacts?per_page=100',
      ),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (artifactsResponse.statusCode != 200) {
      throw Exception('Failed to fetch artifacts');
    }
    final artifactsJson =
        jsonDecode(artifactsResponse.body)['artifacts'] as List<dynamic>;

    // Fetch PRs
    final prsResponse = await http.get(
      Uri.parse(
        'https://api.github.com/repos/$owner/$repo/pulls?state=open&sort=updated&direction=desc',
      ),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (prsResponse.statusCode != 200) {
      throw Exception('Failed to fetch PRs');
    }
    final prsJson = jsonDecode(prsResponse.body) as List<dynamic>;

    // Keep only FOTA artifacts
    final fotaArtifacts = artifactsJson
        .where((a) {
          final name = a['name'] as String? ?? '';
          return name.contains('fota');
        })
        .cast<Map<String, dynamic>>()
        .toList();

    final result = <RemoteFirmware>[];

    for (final pr in prsJson) {
      final prBranch = pr['head']['ref'] as String;
      final prTitle = pr['title'] as String;

      // all artifacts for this PR branch
      final matches = fotaArtifacts.where((artifact) {
        final run = artifact['workflow_run'] as Map<String, dynamic>?;
        final branch = run?['head_branch'] as String?;
        return branch == prBranch;
      }).toList();

      if (matches.isEmpty) continue; // hide PRs with no builds

      matches.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] as String);
        final dateB = DateTime.parse(b['created_at'] as String);
        return dateB.compareTo(dateA);
      });

      final latest = matches.first;

      result.add(RemoteFirmware(
        name: prTitle,
        url: latest['archive_download_url'] as String,
        version: (latest['workflow_run'] as Map<String, dynamic>)['head_sha']
            as String,
        type: FirmwareType.multiImage,
      ));
    }

    // Optional: sort PRs by newest artifact overall
    result.sort((a, b) => b.version.compareTo(a.version));

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Beta Firmware (PR Builds)'),
      ),
      body: Material(
        type: MaterialType.transparency,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    return Container(
      alignment: Alignment.center,
      child: FutureBuilder<List<RemoteFirmware>>(
        future: _firmwareFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            List<RemoteFirmware> apps = snapshot.data!;
            if (apps.isEmpty) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bug_report, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  PlatformText(
                    'No Beta Firmware Available',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: PlatformText(
                      'No pull request builds are currently available.\n\n'
                      'Beta firmware is built automatically from GitHub pull requests.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PlatformElevatedButton(
                    onPressed: () {
                      setState(_loadFirmwares);
                    },
                    child: PlatformText('Refresh'),
                  ),
                ],
              );
            }
            return _listBuilder(apps);
          } else if (snapshot.hasError) {
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  PlatformText(
                    'Error Loading Beta Firmware',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: PlatformText(
                      'Could not fetch beta firmware from GitHub.\n\n'
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PlatformElevatedButton(
                    onPressed: () {
                      setState(_loadFirmwares);
                    },
                    child: PlatformText('Retry'),
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
        // Warning banner
        Container(
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
        ),
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
            remarks.add('Beta');

            return ListTile(
              leading: Icon(Icons.bug_report, color: Colors.orange),
              title: PlatformText(
                firmware.name,
                style: TextStyle(
                  color: isLatest ? Colors.black : Colors.grey,
                ),
              ),
              subtitle: PlatformText(
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
                            final selectedFW = apps[index];
                            context
                                .read<FirmwareUpdateRequestProvider>()
                                .setFirmware(selectedFW);
                            Navigator.of(context).pop();
                            Navigator.pop(context);
                          },
                          child: PlatformText('Install Anyway'),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Show warning for beta firmware
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
                            final selectedFW = apps[index];
                            context
                                .read<FirmwareUpdateRequestProvider>()
                                .setFirmware(selectedFW);
                            Navigator.of(context).pop();
                            Navigator.pop(context);
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
              },
            );
          },
        ),
        if (apps.length > 1)
          PlatformTextButton(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlatformText(
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
