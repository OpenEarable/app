import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

/// Controls how a setting should be applied when a stereo pair is available.
enum StereoPairApplyScope {
  userSelectable,
  individualOnly,
  pairOnly,
}

/// Builds the error message shown when loading the current setting fails.
typedef SelectionLoadErrorBuilder = String Function(Object error);

/// Builds the error message shown when applying a setting fails.
typedef SelectionApplyErrorBuilder = String Function(
  Object error, {
  required bool primaryApplied,
  required bool appliedToPair,
});

/// Renders a reusable option selector for device settings that can target a stereo pair.
///
/// The widget owns the pair-resolution logic, current-value loading, pair-only /
/// individual-only behavior, and the selectable option grid. Concrete settings
/// provide capability accessors and presentation details through callbacks.
class StereoPairOptionSelector<T, M> extends StatefulWidget {
  /// The wearable whose setting should be edited.
  final Wearable device;

  /// Defines whether changes can affect the paired device.
  final StereoPairApplyScope applyScope;

  /// The section title.
  final String title;

  /// The explanatory text shown below the title.
  final String description;

  /// Returns whether the wearable supports the managed setting.
  final bool Function(Wearable device) supportsSetting;

  /// Resolves the setting manager from a supporting wearable.
  final M Function(Wearable device) managerFor;

  /// Reads the currently active selection from a manager.
  final Future<T> Function(M manager) readSelection;

  /// Applies a selection to a manager.
  final Future<void> Function(M manager, T selection) applySelection;

  /// Lists the available options for a manager.
  final Iterable<T> Function(M manager) optionsFor;

  /// Checks whether a manager supports a specific option.
  final bool Function(M manager, T selection) supportsOption;

  /// Compares two options for logical equality.
  final bool Function(T? a, T b) equalsSelection;

  /// Builds the label shown for an option.
  final String Function(T selection) optionLabel;

  /// Builds the subtitle shown for an option.
  final String Function(T selection) optionSubtitle;

  /// Chooses the leading icon shown for an option.
  final IconData Function(T selection) optionIcon;

  /// Builds an optional pill badge shown beside the option label.
  final String? Function(T selection)? optionBadgeText;

  /// Formats load failures.
  final SelectionLoadErrorBuilder loadErrorText;

  /// Formats apply failures.
  final SelectionApplyErrorBuilder applyErrorText;

  /// Number of columns to use once enough width is available.
  final int wideColumns;

  /// Minimum width before switching from one to [wideColumns] columns.
  final double wideLayoutMinWidth;

  const StereoPairOptionSelector({
    super.key,
    required this.device,
    this.applyScope = StereoPairApplyScope.userSelectable,
    required this.title,
    required this.description,
    required this.supportsSetting,
    required this.managerFor,
    required this.readSelection,
    required this.applySelection,
    required this.optionsFor,
    required this.supportsOption,
    required this.equalsSelection,
    required this.optionLabel,
    required this.optionSubtitle,
    required this.optionIcon,
    this.optionBadgeText,
    required this.loadErrorText,
    required this.applyErrorText,
    this.wideColumns = 2,
    this.wideLayoutMinWidth = 420,
  });

  @override
  State<StereoPairOptionSelector<T, M>> createState() =>
      _StereoPairOptionSelectorState<T, M>();
}

class _StereoPairOptionSelectorState<T, M>
    extends State<StereoPairOptionSelector<T, M>> {
  T? _selectedSelection;
  T? _primarySelection;
  T? _pairedSelection;
  M? _pairedManager;
  Wearable? _pairedWearable;
  String _primarySideBadge = 'L';
  String _pairedSideBadge = 'R';
  bool _pairSelectionsDiffer = false;
  bool _isLoading = true;
  bool _isApplying = false;
  bool _applyToStereoPair = false;
  String? _errorText;

  /// The manager used for the currently selected primary device.
  M get _manager => widget.managerFor(widget.device);

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(covariant StereoPairOptionSelector<T, M> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device ||
        oldWidget.applyScope != widget.applyScope) {
      _loadState();
    }
  }

  /// Loads the primary and paired selections and prepares the UI state.
  Future<void> _loadState() async {
    setState(() {
      _isLoading = true;
      _isApplying = false;
      _errorText = null;
    });

    final wearables = context.read<WearablesProvider>().wearables;

    try {
      final primarySelection = await widget.readSelection(_manager);
      final pairedWearable = await _findPairedWearable(wearables: wearables);

      M? pairedManager;
      T? pairedSelection;
      if (pairedWearable != null && widget.supportsSetting(pairedWearable)) {
        final resolvedPairedManager = widget.managerFor(pairedWearable);
        pairedManager = resolvedPairedManager;
        pairedSelection = await widget.readSelection(resolvedPairedManager);
      }

      final positions = await Future.wait<DevicePosition?>([
        _readStereoPosition(widget.device),
        if (pairedWearable != null) _readStereoPosition(pairedWearable),
      ]);

      final pairSelectionsDiffer = pairedSelection != null &&
          !widget.equalsSelection(primarySelection, pairedSelection);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedSelection = pairSelectionsDiffer &&
                widget.applyScope == StereoPairApplyScope.pairOnly
            ? null
            : primarySelection;
        _primarySelection = primarySelection;
        _pairedSelection = pairedSelection;
        _pairedManager = pairedManager;
        _pairedWearable = pairedWearable;
        _primarySideBadge = _sideBadgeForPosition(
          positions.isNotEmpty ? positions.first : null,
          fallback: 'L',
        );
        _pairedSideBadge = _sideBadgeForPosition(
          positions.length > 1 ? positions[1] : null,
          fallback: 'R',
        );
        _pairSelectionsDiffer = pairSelectionsDiffer;
        _applyToStereoPair = switch (widget.applyScope) {
          StereoPairApplyScope.pairOnly => pairedManager != null,
          StereoPairApplyScope.individualOnly => false,
          StereoPairApplyScope.userSelectable => pairedManager != null,
        };
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = widget.loadErrorText(error);
        _isLoading = false;
      });
    }
  }

  /// Resolves the wearable that represents the other side of the stereo pair.
  Future<Wearable?> _findPairedWearable({
    required List<Wearable> wearables,
  }) async {
    if (!widget.device.hasCapability<StereoDevice>()) {
      return null;
    }

    final pairedStereo =
        await widget.device.requireCapability<StereoDevice>().pairedDevice;
    if (pairedStereo == null) {
      return null;
    }

    for (final candidate in wearables) {
      if (candidate.deviceId == widget.device.deviceId) {
        continue;
      }
      if (!candidate.hasCapability<StereoDevice>()) {
        continue;
      }
      if (identical(
        candidate.requireCapability<StereoDevice>(),
        pairedStereo,
      )) {
        return candidate;
      }
    }

    return null;
  }

  /// Reads the stereo position so mismatch badges can show left and right sides.
  Future<DevicePosition?> _readStereoPosition(Wearable wearable) async {
    if (!wearable.hasCapability<StereoDevice>()) {
      return null;
    }
    try {
      return await wearable.requireCapability<StereoDevice>().position;
    } catch (_) {
      return null;
    }
  }

  /// Applies the chosen setting to the primary device and optionally to the pair.
  Future<void> _onSelectionChosen(T selection) async {
    if (_isApplying || _isLoading) {
      return;
    }

    final previousSelection = _selectedSelection;
    final previousPrimarySelection = _primarySelection;
    final previousPairedSelection = _pairedSelection;
    final previousPairSelectionsDiffer = _pairSelectionsDiffer;
    final shouldApplyToPair = switch (widget.applyScope) {
      StereoPairApplyScope.pairOnly => true,
      StereoPairApplyScope.individualOnly => false,
      StereoPairApplyScope.userSelectable => _applyToStereoPair,
    };
    final pairedManager = shouldApplyToPair ? _pairedManager : null;

    setState(() {
      _selectedSelection = selection;
      _primarySelection = selection;
      if (pairedManager != null) {
        _pairedSelection = selection;
      }
      _pairSelectionsDiffer = false;
      _isApplying = true;
      _errorText = null;
    });

    var primaryApplied = false;
    try {
      await widget.applySelection(_manager, selection);
      primaryApplied = true;

      if (pairedManager != null) {
        if (!widget.supportsOption(pairedManager, selection)) {
          throw StateError(
            'Paired device does not support ${widget.optionLabel(selection)}.',
          );
        }
        await widget.applySelection(pairedManager, selection);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (!primaryApplied || pairedManager == null) {
          _selectedSelection = previousSelection;
          _primarySelection = previousPrimarySelection;
          _pairedSelection = previousPairedSelection;
          _pairSelectionsDiffer = previousPairSelectionsDiffer;
        } else if (widget.applyScope == StereoPairApplyScope.pairOnly) {
          _selectedSelection = null;
          _primarySelection = selection;
          _pairedSelection = previousPairedSelection;
          _pairSelectionsDiffer = true;
        }
        _errorText = widget.applyErrorText(
          error,
          primaryApplied: primaryApplied,
          appliedToPair: pairedManager != null,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  /// Converts a device position into the short side badge shown in pair mismatch mode.
  String _sideBadgeForPosition(
    DevicePosition? position, {
    required String fallback,
  }) {
    return switch (position) {
      DevicePosition.left => 'L',
      DevicePosition.right => 'R',
      _ => fallback,
    };
  }

  /// Builds the shared option grid used by all pair-aware selectors.
  Widget _buildOptions(List<T> options) {
    final showPairSideBadges =
        widget.applyScope != StereoPairApplyScope.individualOnly &&
            _pairedManager != null &&
            _pairSelectionsDiffer;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth >= widget.wideLayoutMinWidth
            ? widget.wideColumns
            : 1;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: options.map((option) {
            final sideBadges = <String>[
              if (showPairSideBadges &&
                  _primarySelection != null &&
                  widget.equalsSelection(_primarySelection, option))
                _primarySideBadge,
              if (showPairSideBadges &&
                  _pairedSelection != null &&
                  widget.equalsSelection(_pairedSelection, option))
                _pairedSideBadge,
            ];

            return SizedBox(
              width: itemWidth,
              child: _SelectionOptionButton(
                label: widget.optionLabel(option),
                subtitle: widget.optionSubtitle(option),
                icon: widget.optionIcon(option),
                badgeText: widget.optionBadgeText?.call(option),
                selected: _selectedSelection != null &&
                    widget.equalsSelection(_selectedSelection, option),
                sideBadges: sideBadges,
                enabled: !_isApplying && !_isLoading,
                onTap: () => _onSelectionChosen(option),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.optionsFor(_manager).toList();
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final pairName = _pairedWearable?.name;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          if (_pairedManager != null &&
              widget.applyScope == StereoPairApplyScope.userSelectable)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _applyToStereoPair,
              onChanged: _isApplying || _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _applyToStereoPair = value;
                      });
                    },
              title: const Text('Apply to stereo pair'),
              subtitle: Text(
                _applyToStereoPair
                    ? pairName == null
                        ? 'Left and right devices change together.'
                        : 'Also update $pairName.'
                    : 'Only update this device.',
              ),
            ),
          const SizedBox(height: 6),
          _buildOptions(options),
          if (_isApplying) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable visual representation for a selectable setting option.
class _SelectionOptionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final String? badgeText;
  final bool selected;
  final List<String> sideBadges;
  final bool enabled;
  final VoidCallback onTap;

  const _SelectionOptionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    this.badgeText,
    required this.selected,
    this.sideBadges = const [],
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final foregroundColor =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final iconColor =
        enabled ? foregroundColor : foregroundColor.withValues(alpha: 0.55);
    final titleColor = enabled
        ? (selected ? colorScheme.primary : colorScheme.onSurface)
        : colorScheme.onSurface.withValues(alpha: 0.55);
    final subtitleColor = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.55);

    final backgroundColor = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.44)
        : colorScheme.surface;
    final borderColor = selected
        ? colorScheme.primary.withValues(alpha: 0.7)
        : colorScheme.outlineVariant.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          _SelectorPillBadge(label: badgeText!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (sideBadges.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: sideBadges
                      .map((badge) => _SelectorSideBadge(label: badge))
                      .toList(),
                ),
              ],
              if (sideBadges.isEmpty)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared pill badge for option labels such as beta indicators.
class _SelectorPillBadge extends StatelessWidget {
  final String label;

  const _SelectorPillBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Shared side badge that marks which ear currently uses an option.
class _SelectorSideBadge extends StatelessWidget {
  final String label;

  const _SelectorSideBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
