import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_wearable/models/connector_settings.dart';

/// Compact global status chip shown while an external connector is active.
class ConnectorActivityIndicator extends StatelessWidget {
  const ConnectorActivityIndicator({
    super.key,
    this.statusListenable,
  });

  /// Runtime status source. Tests may inject a notifier without touching the
  /// process-wide connector service.
  final ValueListenable<ConnectorRuntimeStatus>? statusListenable;

  @override
  Widget build(BuildContext context) {
    final listenable =
        statusListenable ?? ConnectorSettings.webSocketRuntimeStatusListenable;

    return ValueListenableBuilder<ConnectorRuntimeStatus>(
      valueListenable: listenable,
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
            alignment: AlignmentDirectional.topEnd,
            child: Semantics(
              label: label,
              liveRegion: true,
              child: Semantics(
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
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
