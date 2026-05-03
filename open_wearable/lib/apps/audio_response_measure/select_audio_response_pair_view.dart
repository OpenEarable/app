import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/models/app_compatibility.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

/// Selection screen for the Audio Response app.
///
/// Lists compatible wearables, automatically combining stereo pairs into one
/// entry. The caller receives the left and/or right [AudioResponseManager]
/// once the user presses "Start App".
class SelectAudioResponsePairView extends StatefulWidget {
  final Future<Widget> Function(
    AudioResponseManager? left,
    AudioResponseManager? right,
  ) startApp;
  final List<AppSupportOption> supportedDevices;

  const SelectAudioResponsePairView({
    super.key,
    required this.startApp,
    this.supportedDevices = const [],
  });

  @override
  State<SelectAudioResponsePairView> createState() =>
      _SelectAudioResponsePairViewState();
}

class _SelectAudioResponsePairViewState
    extends State<SelectAudioResponsePairView> {
  /// DeviceId of the selected group representative (primary wearable).
  String? _selectedGroupId;
  Future<List<WearableDisplayGroup>>? _groupsFuture;
  String _groupFingerprint = '';
  bool _isStartingApp = false;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Select Wearable'),
      ),
      body: Consumer<WearablesProvider>(
        builder: (context, wearablesProvider, _) {
          final compatibleWearables = wearablesProvider.wearables
              .where(
                (w) => wearableIsCompatibleWithApp(
                  wearable: w,
                  supportedDevices: widget.supportedDevices,
                ),
              )
              .toList(growable: false);

          _refreshGroupsIfNeeded(compatibleWearables);

          return Column(
            children: [
              Expanded(
                child: _buildBody(context, compatibleWearables),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: PlatformElevatedButton(
                    onPressed: _selectedGroupId != null && !_isStartingApp
                        ? () => _startSelected(wearablesProvider, compatibleWearables)
                        : null,
                    child: _isStartingApp
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: PlatformCircularProgressIndicator(),
                          )
                        : PlatformText('Start App'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _refreshGroupsIfNeeded(List<Wearable> wearables) {
    final fingerprint =
        wearables.map((w) => '${w.deviceId}:${w.name}').join('|');
    if (_groupsFuture != null && _groupFingerprint == fingerprint) return;
    _groupFingerprint = fingerprint;
    _groupsFuture = buildWearableDisplayGroups(
      wearables,
      // Combine pairs so stereo earables appear as one entry
      shouldCombinePair: (_, __) => true,
    );
  }

  Widget _buildBody(BuildContext context, List<Wearable> compatibleWearables) {
    if (compatibleWearables.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'No compatible wearables connected for this app.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return FutureBuilder<List<WearableDisplayGroup>>(
      future: _groupsFuture,
      builder: (context, snapshot) {
        final groups = snapshot.data ??
            compatibleWearables
                .map((w) => WearableDisplayGroup.single(wearable: w))
                .toList(growable: false);

        if (groups.isEmpty) return const SizedBox.shrink();

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final isSelected = _selectedGroupId == group.primary.deviceId;
            return _GroupCard(
              group: group,
              selected: isSelected,
              onTap: () => setState(() {
                _selectedGroupId = group.primary.deviceId;
              }),
            );
          },
        );
      },
    );
  }

  Future<void> _startSelected(
    WearablesProvider wearablesProvider,
    List<Wearable> compatibleWearables,
  ) async {
    if (_selectedGroupId == null) return;

    // Rebuild groups to find the selected one
    final groups = await (buildWearableDisplayGroups(
      compatibleWearables,
      shouldCombinePair: (_, __) => true,
    ));

    final group = groups
        .where((g) => g.primary.deviceId == _selectedGroupId)
        .firstOrNull;
    if (group == null) return;

    AudioResponseManager? leftManager;
    AudioResponseManager? rightManager;

    if (group.isCombined) {
      final left = group.leftDevice;
      final right = group.rightDevice;
      leftManager = left?.getCapability<AudioResponseManager>();
      rightManager = right?.getCapability<AudioResponseManager>();
    } else {
      final manager = group.primary.getCapability<AudioResponseManager>();
      // Assign to left or right based on known position, default to left
      if (group.primaryPosition == DevicePosition.right) {
        rightManager = manager;
      } else {
        leftManager = manager;
      }
    }

    if (leftManager == null && rightManager == null) return;

    final navigator = Navigator.of(context);
    setState(() => _isStartingApp = true);

    navigator.push(
      platformPageRoute(
        context: context,
        builder: (context) => const _LoadingScreen(),
      ),
    );

    try {
      final app = await widget.startApp(leftManager, rightManager);
      if (!mounted) return;
      navigator.pushReplacement(
        platformPageRoute(
          context: context,
          builder: (context) => app,
        ),
      );
    } catch (_) {
      if (navigator.canPop()) navigator.pop();
      rethrow;
    } finally {
      if (mounted) setState(() => _isStartingApp = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Group card
// ---------------------------------------------------------------------------

class _GroupCard extends StatelessWidget {
  final WearableDisplayGroup group;
  final bool selected;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: selected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon placeholder
              const SizedBox(width: 40, height: 40,
                child: Icon(Icons.headphones, size: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.isCombined
                          ? group.displayName
                          : formatWearableDisplayName(group.primary.name),
                      style: theme.textTheme.titleSmall,
                    ),
                    if (group.isCombined)
                      Text(
                        'Left + Right',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.primary),
                      )
                    else if (group.primaryPosition != null)
                      Text(
                        group.primaryPosition == DevicePosition.left
                            ? 'Left'
                            : 'Right',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                    Text(
                      group.primary.deviceId,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (group.isCombined && group.secondary != null)
                      Text(
                        group.secondary!.deviceId,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading screen
// ---------------------------------------------------------------------------

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(title: PlatformText('Starting…')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
