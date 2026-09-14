import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/widgets/app_compatibility.dart';
import 'package:open_wearable/models/device_name_formatter.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/devices/device_status_pills.dart';
import 'package:open_wearable/widgets/devices/wearable_icon.dart';
import 'package:provider/provider.dart';

/// Lets the user choose a compatible wearable before launching an app.
class SelectEarableView extends StatefulWidget {
  final Future<Widget> Function(
    Wearable,
    SensorConfigurationProvider,
  ) startApp;
  final List<String> supportedDevicePrefixes;
  final List<WearableCapabilityRequirement> requiredCapabilities;

  const SelectEarableView({
    super.key,
    required this.startApp,
    this.supportedDevicePrefixes = const [],
    this.requiredCapabilities = const [],
  });

  @override
  State<SelectEarableView> createState() => _SelectEarableViewState();
}

class _SelectEarableViewState extends State<SelectEarableView> {
  Wearable? _selectedWearable;
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
          final supportedWearables = wearablesProvider.wearables
              .where(
                (wearable) => wearableMatchesSupportedDevicePrefixes(
                  wearable: wearable,
                  supportedDevicePrefixes: widget.supportedDevicePrefixes,
                ),
              )
              .toList(growable: false);
          final selectableWearables = supportedWearables
              .where(
                (wearable) => _missingRequirements(wearable).isEmpty,
              )
              .toList(growable: false);

          _refreshGroupFutureIfNeeded(supportedWearables);
          final selectedDeviceId = _selectedWearable?.deviceId;
          final hasSelectedCompatibleWearable = selectedDeviceId != null &&
              selectableWearables.any(
                (wearable) => wearable.deviceId == selectedDeviceId,
              );

          return Column(
            children: [
              Expanded(
                child: _buildBody(
                  context,
                  supportedWearables: supportedWearables,
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: PlatformElevatedButton(
                    onPressed: hasSelectedCompatibleWearable && !_isStartingApp
                        ? () => _startSelectedApp(
                              wearablesProvider,
                              selectableWearables,
                            )
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

  void _refreshGroupFutureIfNeeded(List<Wearable> wearables) {
    final fingerprint = wearables
        .map((wearable) => '${wearable.deviceId}:${wearable.name}')
        .join('|');
    if (_groupsFuture != null && _groupFingerprint == fingerprint) {
      return;
    }

    _groupFingerprint = fingerprint;
    _groupsFuture = buildWearableDisplayGroups(
      wearables,
      shouldCombinePair: (_, __) => false,
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<Wearable> supportedWearables,
  }) {
    if (supportedWearables.isEmpty) {
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
        final groups = _sortGroupsForSelection(
          snapshot.data ??
              supportedWearables
                  .map(
                    (wearable) =>
                        WearableDisplayGroup.single(wearable: wearable),
                  )
                  .toList(growable: false),
        );

        if (groups.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedId = _selectedWearable?.deviceId;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final wearable = group.primary;
            final missingRequirements = _missingRequirements(wearable);
            final isSelectable = missingRequirements.isEmpty;
            final isSelected = isSelectable && selectedId == wearable.deviceId;

            return _SelectableWearableCard(
              wearable: wearable,
              position: group.primaryPosition,
              selected: isSelected,
              disabledReason: _disabledReason(missingRequirements),
              onTap: isSelectable
                  ? () {
                      setState(() {
                        _selectedWearable = wearable;
                      });
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  List<WearableDisplayGroup> _sortGroupsForSelection(
    List<WearableDisplayGroup> groups,
  ) {
    final indexed = groups.asMap().entries.toList();

    String normalizedName(String name) {
      var value = name.trim();
      value = value.replaceFirst(
        RegExp(r'\s*\((left|right|l|r)\)$', caseSensitive: false),
        '',
      );
      value = value.replaceFirst(
        RegExp(r'[\s_-]+(left|right|l|r)$', caseSensitive: false),
        '',
      );
      value = value.trim();
      return value.isEmpty ? name.trim() : value;
    }

    int positionRank(DevicePosition? position) {
      return switch (position) {
        DevicePosition.left => 0,
        DevicePosition.right => 1,
        _ => 2,
      };
    }

    indexed.sort((a, b) {
      final bySelectable = _selectableRank(a.value.primary)
          .compareTo(_selectableRank(b.value.primary));
      if (bySelectable != 0) {
        return bySelectable;
      }

      final aBase = normalizedName(a.value.primary.name).toLowerCase();
      final bBase = normalizedName(b.value.primary.name).toLowerCase();
      final byBase = aBase.compareTo(bBase);
      if (byBase != 0) {
        return byBase;
      }

      final byPosition = positionRank(a.value.primaryPosition)
          .compareTo(positionRank(b.value.primaryPosition));
      if (byPosition != 0) {
        return byPosition;
      }

      final byName = a.value.primary.name
          .toLowerCase()
          .compareTo(b.value.primary.name.toLowerCase());
      if (byName != 0) {
        return byName;
      }

      return a.key.compareTo(b.key);
    });

    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  int _selectableRank(Wearable wearable) {
    return _missingRequirements(wearable).isEmpty ? 0 : 1;
  }

  List<WearableCapabilityRequirement> _missingRequirements(Wearable wearable) {
    return missingWearableCapabilityRequirements(
      wearable: wearable,
      requirements: widget.requiredCapabilities,
    );
  }

  String? _disabledReason(List<WearableCapabilityRequirement> requirements) {
    if (requirements.isEmpty) {
      return null;
    }

    final labels =
        requirements.map((requirement) => requirement.label).join(', ');
    return 'Missing $labels';
  }

  Future<void> _startSelectedApp(
    WearablesProvider wearablesProvider,
    List<Wearable> selectableWearables,
  ) async {
    final selectedId = _selectedWearable?.deviceId;
    if (selectedId == null) {
      return;
    }

    final selectedWearable = selectableWearables
        .where((wearable) => wearable.deviceId == selectedId)
        .firstOrNull;

    if (selectedWearable == null) {
      return;
    }

    final sensorConfigProvider =
        wearablesProvider.getSensorConfigurationProvider(selectedWearable);
    final navigator = Navigator.of(context);

    setState(() {
      _isStartingApp = true;
    });

    navigator.push(
      platformPageRoute(
        context: context,
        builder: (context) => const _AppStartupLoadingScreen(),
      ),
    );

    try {
      final app = await widget.startApp(
        selectedWearable,
        sensorConfigProvider,
      );

      if (!mounted) {
        return;
      }

      navigator.pushReplacement(
        platformPageRoute(
          context: context,
          builder: (context) => ChangeNotifierProvider.value(
            value: sensorConfigProvider,
            child: app,
          ),
        ),
      );
    } catch (_) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isStartingApp = false;
        });
      }
    }
  }
}

class _AppStartupLoadingScreen extends StatelessWidget {
  const _AppStartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Starting App'),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlatformCircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Preparing app...'),
          ],
        ),
      ),
    );
  }
}

class _SelectableWearableCard extends StatelessWidget {
  final Wearable wearable;
  final DevicePosition? position;
  final bool selected;
  final String? disabledReason;
  final VoidCallback? onTap;

  const _SelectableWearableCard({
    required this.wearable,
    required this.position,
    required this.selected,
    required this.disabledReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconVariant = _iconVariantForPosition(position);
    final hasWearableIcon = _hasWearableIcon(iconVariant);
    final isEnabled = onTap != null;
    final disabledCardColor = theme.brightness == Brightness.dark
        ? const Color(0xFF2E2E2E)
        : const Color(0xFFE7E7E7);
    final disabledTextColor = theme.brightness == Brightness.dark
        ? const Color(0xFFB8B8B8)
        : const Color(0xFF6F6F6F);
    final cardColor = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.34)
        : isEnabled
            ? colorScheme.surface
            : disabledCardColor;
    final pills = _buildDeviceStatusPills();

    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: _DisabledGreyscale(
          enabled: !isEnabled,
          child: Opacity(
            opacity: isEnabled ? 1 : 0.66,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasWearableIcon) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: WearableIcon(
                          wearable: wearable,
                          initialVariant: iconVariant,
                          hideWhileResolvingStereoPosition: true,
                          hideWhenResolvedVariantIsSingle: true,
                          fallback: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                formatWearableDisplayName(wearable.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isEnabled ? null : disabledTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Text(
                                wearable.deviceId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isEnabled
                                      ? theme.colorScheme.onSurfaceVariant
                                      : disabledTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (disabledReason case final reason?) ...[
                          const SizedBox(height: 6),
                          Text(
                            reason,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: disabledTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (pills.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildStatusPillLine(pills),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  WearableIconVariant _iconVariantForPosition(DevicePosition? position) {
    return switch (position) {
      DevicePosition.left => WearableIconVariant.left,
      DevicePosition.right => WearableIconVariant.right,
      _ => WearableIconVariant.single,
    };
  }

  bool _hasWearableIcon(WearableIconVariant initialVariant) {
    return WearableIcon.hasIcon(wearable, variant: initialVariant);
  }

  List<Widget> _buildDeviceStatusPills() {
    String? sideLabel;
    if (position == DevicePosition.left) {
      sideLabel = 'L';
    } else if (position == DevicePosition.right) {
      sideLabel = 'R';
    }

    return buildDeviceStatusPills(
      wearable: wearable,
      sideLabel: sideLabel,
      showStereoPosition: sideLabel == null,
      batteryLiveUpdates: true,
      batteryShowBackground: true,
    );
  }

  Widget _buildStatusPillLine(List<Widget> pills) {
    return DevicePillLine(pills: pills);
  }
}

class _DisabledGreyscale extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _DisabledGreyscale({
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: child,
    );
  }
}
