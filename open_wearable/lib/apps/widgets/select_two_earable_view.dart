import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';

import '../../view_models/sensor_configuration_provider.dart';
import '../../view_models/wearables_provider.dart';

/// A screen to pick two earables (left & right) devices
class SelectTwoEarableView extends StatefulWidget {
  final Widget Function(
    Wearable leftWearable,
    SensorConfigurationProvider leftProv,
    Wearable rightWearable,
    SensorConfigurationProvider rightProv,
  ) startApp;

  const SelectTwoEarableView({super.key, required this.startApp});

  @override
  State<SelectTwoEarableView> createState() => _SelectTwoEarableViewState();
}

class _SelectTwoEarableViewState extends State<SelectTwoEarableView> {
  Wearable? _left;
  Wearable? _right;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<WearablesProvider>();
    final wearables = prov.wearables;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Pick two earables'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          // If your provider supports rescanning, trigger it here.
          // For now just rebuild.
          // TODO: connect devices
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _selectionHeader(context),

            // Section A — Suggested pairs
            FutureBuilder<List<_PairCardModel>>(
              future: _buildSuggestedPairs(wearables),
              builder: (context, snap) {
                final pairs = snap.data ?? const [];
                if (pairs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(context, 'Suggested pairs'),
                    const SizedBox(height: 8),
                    ...pairs.map((p) => _PairCard(
                          model: p,
                          onUseBoth: () {
                            setState(() {
                              _left = p.left;
                              _right = p.right;
                            });
                          },
                          onSwap: () {
                            setState(() {
                              final l = p.left;
                              p.left = p.right;
                              p.right = l;
                            });
                          },
                        ),),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // Section B — All devices
            _sectionTitle(context, 'All devices'),
            const SizedBox(height: 8),
            ...wearables.map((w) => _deviceTile(context, w, prov, wearables)),
            const SizedBox(height: 24),

            PlatformElevatedButton(
              onPressed: (_left != null && _right != null && !identical(_left, _right))
                  ? () {
                      final leftProv = prov.getSensorConfigurationProvider(_left!);
                      final rightProv = prov.getSensorConfigurationProvider(_right!);
                      Navigator.of(context).push(platformPageRoute(
                        context: context,
                        builder: (_) => MultiProvider(
                          providers: [
                            ChangeNotifierProvider.value(value: leftProv),
                            ChangeNotifierProvider.value(value: rightProv),
                          ],
                          child: widget.startApp(_left!, leftProv, _right!, rightProv),
                        ),
                      ),);
                    }
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: UI bits

  Widget _selectionHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _slotChip(context, 'Left', _left, onClear: () => setState(() => _left = null)),
          if (_left != null && _right != null)
            PlatformIconButton(
              icon: Icon(Icons.swap_vert),
              onPressed: () => setState(() {
                final t = _left;
                _left = _right;
                _right = t;
              }),
            ),
          _slotChip(context, 'Right', _right, onClear: () => setState(() => _right = null)),
        ],
      ),
    );
  }

  Widget _slotChip(BuildContext context, String label, Wearable? w, {VoidCallback? onClear}) {
    return InputChip(
      label: Row(children: [
        Text('$label: ${w?.name ?? '—'}'),
        if (w != null)
          _StereoBadge(wearable: w),
      ],),
      onDeleted: w != null ? onClear : null,
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _deviceTile(
    BuildContext context,
    Wearable w,
    WearablesProvider prov,
    List<Wearable> available,
  ) {
    return PlatformListTile(
      title: _DeviceNameAndBadge(wearable: w),
      trailing: Wrap(
        spacing: 8,
        children: [
          if (identical(_left, w)) Icon(context.platformIcons.checkMark),
          if (identical(_right, w)) Icon(context.platformIcons.checkMark),
          PlatformIconButton(
            icon: Icon(context.platformIcons.ellipsis),
            onPressed: () => _showDeviceActions(context, w, available),
            cupertino: (_, __) => CupertinoIconButtonData(padding: EdgeInsets.zero),
          ),
        ],
      ),
      // Simple tap assigns to the first empty slot; otherwise reassigns Right.
      onTap: () async {
        setState(() {
          if (_left == null && !identical(_right, w)) {
            _left = w;
          } else if (_right == null && !identical(_left, w)) {
            _right = w;
          } else if (!identical(_left, w) && !identical(_right, w)) {
            // both filled → replace Right by default
            _right = w;
          }
        });
      },
    );
  }

  void _showDeviceActions(BuildContext context, Wearable w, List<Wearable> available) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chevron_left),
                title: const Text('Assign to Left'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (!identical(_right, w)) _left = w;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.chevron_right),
                title: const Text('Assign to Right'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (!identical(_left, w)) _right = w;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Pair building & suggestions ------------------------------------------

  Future<List<_PairCardModel>> _buildSuggestedPairs(List<Wearable> all) async {
    final List<_PairCardModel> out = [];
    final seen = <Wearable>{};

    for (final w in all) {
      if (seen.contains(w)) continue;
      if (w is! StereoDevice) continue;
      final StereoDevice? p = await (w as StereoDevice).pairedDevice;
      if (p == null && p is! Wearable) continue;
      final Wearable partner = p as Wearable;
      if (!seen.contains(partner)) {
        
        final (left, right) = await _normalizeLR(w, partner);
        out.add(_PairCardModel(left: left, right: right, label: _pairLabel(left, right)));
        seen.addAll([w, partner]);
      }
    }

    // Remove duplicates (same pair different order)
    return _dedupPairs(out);
  }

  List<_PairCardModel> _dedupPairs(List<_PairCardModel> input) {
    final set = <String>{};
    final out = <_PairCardModel>[];
    for (final p in input) {
      final key = '${identityHashCode(p.left)}-${identityHashCode(p.right)}';
      final key2 = '${identityHashCode(p.right)}-${identityHashCode(p.left)}';
      if (set.contains(key) || set.contains(key2)) continue;
      set.add(key);
      out.add(p);
    }
    return out;
  }

  Future<(Wearable left, Wearable right)> _normalizeLR(Wearable a, Wearable b) async {
    final DevicePosition? pa = await _tryGetPosition(a);
    final DevicePosition? pb = await _tryGetPosition(b);
    if (pa == DevicePosition.left && pb == DevicePosition.right) {
      return (a, b);
    } else if (pa == DevicePosition.right && pb == DevicePosition.left) {
      return (b, a);
    }

    // Default: keep order
    return (a, b);
  }

  String _pairLabel(Wearable left, Wearable right) {
    final base = _baseName(left.name);
    // If both share the same base name, show compact label
    if (_baseName(right.name) == base) return '$base — L/R';
    return '${left.name} (L)  +  ${right.name} (R)';
  }

  Future<DevicePosition?> _tryGetPosition(Wearable w) async {
    if (w is! StereoDevice) return null;
    return await (w as StereoDevice).position;
  }

  String _baseName(String name) {
    final patterns = [
      RegExp(r'\s*[\(\[]?(L|Left)\]?$', caseSensitive: false),
      RegExp(r'\s*[\(\[]?(R|Right)\]?$', caseSensitive: false),
      RegExp(r'\s*-\s*(L|R)$', caseSensitive: false),
    ];
    var base = name.trim();
    for (final p in patterns) {
      base = base.replaceAll(p, '').trim();
    }
    return base;
  }
}

// MARK: UI components
// --- UI components -----------------------------------------------------------

class _PairCardModel {
  _PairCardModel({required this.left, required this.right, required this.label});
  Wearable left;
  Wearable right;
  final String label;
}


// MARK: Pair Card
class _PairCard extends StatelessWidget {
  final _PairCardModel model;
  final VoidCallback onUseBoth;
  final VoidCallback onSwap;

  const _PairCard({
    required this.model,
    required this.onUseBoth,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _pairRowItem('Left', model.left)),
                PlatformIconButton(
                  icon: Icon(Icons.swap_horiz),
                  onPressed: onSwap,
                  cupertino: (_, __) => CupertinoIconButtonData(padding: EdgeInsets.zero),
                ),
                Expanded(child: _pairRowItem('Right', model.right)),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: PlatformElevatedButton(
                onPressed: onUseBoth,
                child: const Text('Select Pair'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pairRowItem(String label, Wearable w) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        _DeviceNameAndBadge(wearable: w),
      ],
    );
  }
}

// MARK: Stereo Badge

class _StereoBadge extends StatelessWidget {
  final Wearable wearable;
  const _StereoBadge({required this.wearable});

  @override
  Widget build(BuildContext context) {
    if (wearable is! StereoDevice) return const SizedBox.shrink();
    return FutureBuilder<DevicePosition?>(
      future: (wearable as StereoDevice).position,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final String label = switch (snap.data) {
          DevicePosition.left => 'L',
          DevicePosition.right => 'R',
          null => 'N/A',
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        );
      },
    );
  }
}

class _DeviceNameAndBadge extends StatelessWidget {
  final Wearable wearable;

  const _DeviceNameAndBadge({required this.wearable});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Flexible(
        child: Text(wearable.name, overflow: TextOverflow.ellipsis),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _StereoBadge(wearable: wearable),
      ),
    ],);
  }
}
