import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_wearable/models/connector_settings.dart';
import 'package:open_wearable/router.dart';

/// Compact global status chip shown while an external connector is active.
class ConnectorActivityIndicator extends StatefulWidget {
  const ConnectorActivityIndicator({
    super.key,
    this.statusListenable,
    this.onOpenSettings,
  });

  /// How long the indicator shows its expanded label before compacting.
  static const Duration expandedDuration = Duration(seconds: 5);

  /// Runtime status source. Tests may inject a notifier without touching the
  /// process-wide connector service.
  final ValueListenable<ConnectorRuntimeStatus>? statusListenable;

  /// Opens connector settings. Defaults to navigating through the app router.
  final VoidCallback? onOpenSettings;

  @override
  State<ConnectorActivityIndicator> createState() =>
      _ConnectorActivityIndicatorState();
}

class _ConnectorActivityIndicatorState
    extends State<ConnectorActivityIndicator> {
  late ValueListenable<ConnectorRuntimeStatus> _statusListenable;
  Timer? _collapseTimer;
  bool _isExpanded = false;
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _statusListenable = _resolveStatusListenable();
    _wasActive = _statusListenable.value.isActive;
    _isExpanded = _wasActive;
    _statusListenable.addListener(_handleStatusChanged);
    if (_isExpanded) {
      _scheduleCollapse();
    }
  }

  @override
  void didUpdateWidget(covariant ConnectorActivityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextStatusListenable = _resolveStatusListenable();
    if (nextStatusListenable == _statusListenable) {
      return;
    }

    _statusListenable.removeListener(_handleStatusChanged);
    _statusListenable = nextStatusListenable;
    _statusListenable.addListener(_handleStatusChanged);
    _syncStateWithStatus(_statusListenable.value);
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _statusListenable.removeListener(_handleStatusChanged);
    super.dispose();
  }

  ValueListenable<ConnectorRuntimeStatus> _resolveStatusListenable() {
    return widget.statusListenable ??
        ConnectorSettings.webSocketRuntimeStatusListenable;
  }

  void _handleStatusChanged() {
    _syncStateWithStatus(_statusListenable.value);
  }

  void _syncStateWithStatus(ConnectorRuntimeStatus status) {
    final isActive = status.isActive;
    if (isActive == _wasActive) {
      return;
    }

    _wasActive = isActive;
    if (!mounted) {
      return;
    }

    setState(() {
      _isExpanded = isActive;
    });

    if (isActive) {
      _scheduleCollapse();
    } else {
      _collapseTimer?.cancel();
      _collapseTimer = null;
    }
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(ConnectorActivityIndicator.expandedDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExpanded = false;
      });
    });
  }

  void _expandTemporarily() {
    if (!_statusListenable.value.isActive) {
      return;
    }
    setState(() {
      _isExpanded = true;
    });
    _scheduleCollapse();
  }

  void _openSettings() {
    final onOpenSettings = widget.onOpenSettings;
    if (onOpenSettings != null) {
      onOpenSettings();
      return;
    }

    rootNavigatorKey.currentContext?.push('/settings/connectors');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectorRuntimeStatus>(
      valueListenable: _statusListenable,
      builder: (context, status, _) {
        if (!status.isActive) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;
        final foregroundColor = status.state == ConnectorRuntimeState.starting
            ? colorScheme.onPrimaryContainer
            : colorScheme.onTertiaryContainer;
        final backgroundColor = status.state == ConnectorRuntimeState.starting
            ? colorScheme.primaryContainer
            : colorScheme.tertiaryContainer;
        final label = status.state == ConnectorRuntimeState.starting
            ? 'Connector starting'
            : 'Connector active';

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _expandTemporarily,
              onLongPress: _openSettings,
              child: Semantics(
                button: true,
                label: label,
                liveRegion: true,
                child: Semantics(
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: foregroundColor.withValues(alpha: 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hub_rounded,
                                size: 14,
                                color: foregroundColor,
                              ),
                              if (_isExpanded) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'Connector',
                                  style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: foregroundColor,
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                          ) ??
                                      TextStyle(
                                        color: foregroundColor,
                                        fontWeight: FontWeight.w800,
                                        height: 1,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
