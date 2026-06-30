import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';

import 'package:open_wearable/apps/study_protocol/model/study_devices.dart';
import 'package:open_wearable/apps/study_protocol/view/study_recordings_list_page.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';

/// Entry point for the study protocol app.
///
/// Gates the experience on a complete device set — a stereo pair of
/// OpenEarables plus a Plux RESPIRABAN — and shows the recordings list once the
/// requirement is met. The gate re-evaluates whenever the connected wearable
/// set changes.
class StudyProtocolApp extends StatefulWidget {
  const StudyProtocolApp({super.key});

  @override
  State<StudyProtocolApp> createState() => _StudyProtocolAppState();
}

class _StudyProtocolAppState extends State<StudyProtocolApp> {
  Future<StudyDeviceSet?>? _deviceSetFuture;
  String _fingerprint = '';

  void _refreshDeviceSetIfNeeded(List<Wearable> wearables) {
    final fingerprint = wearables.map((w) => w.deviceId).join('|');
    if (fingerprint == _fingerprint && _deviceSetFuture != null) {
      return;
    }
    _fingerprint = fingerprint;
    _deviceSetFuture = resolveStudyDeviceSet(wearables);
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Study Protocol'),
      ),
      body: Consumer<WearablesProvider>(
        builder: (context, wearablesProvider, _) {
          final wearables = wearablesProvider.wearables;
          _refreshDeviceSetIfNeeded(wearables);

          return FutureBuilder<StudyDeviceSet?>(
            future: _deviceSetFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final deviceSet = snapshot.data;
              if (deviceSet == null) {
                return _StudyDeviceGate(wearables: wearables);
              }
              return StudyRecordingsList(deviceSet: deviceSet);
            },
          );
        },
      ),
    );
  }
}

/// Checklist shown until the required device set is connected.
class _StudyDeviceGate extends StatelessWidget {
  final List<Wearable> wearables;

  const _StudyDeviceGate({required this.wearables});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final respibanConnected = findRespiban(wearables) != null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          Icons.science_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Connect the required devices',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The study protocol needs a pair of OpenEarables and a Plux '
          'RESPIRABAN connected before you can start a recording.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FutureBuilder<EarablePair?>(
          future: findEarablePair(wearables),
          builder: (context, snapshot) {
            final pairConnected = snapshot.data != null;
            final resolving =
                snapshot.connectionState == ConnectionState.waiting;
            return _RequirementTile(
              label: 'OpenEarable pair (left + right)',
              satisfied: pairConnected,
              loading: resolving,
            );
          },
        ),
        const SizedBox(height: 8),
        _RequirementTile(
          label: 'Plux RESPIRABAN',
          satisfied: respibanConnected,
          loading: false,
        ),
        const SizedBox(height: 24),
        PlatformElevatedButton(
          onPressed: () => context.push('/connect-devices'),
          child: PlatformText('Connect devices'),
        ),
      ],
    );
  }
}

class _RequirementTile extends StatelessWidget {
  final String label;
  final bool satisfied;
  final bool loading;

  const _RequirementTile({
    required this.label,
    required this.satisfied,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget trailing;
    if (loading) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      trailing = Icon(
        satisfied ? Icons.check_circle : Icons.radio_button_unchecked,
        color: satisfied
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          satisfied ? Icons.bluetooth_connected : Icons.bluetooth,
          color: satisfied
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(label),
        trailing: trailing,
      ),
    );
  }
}
