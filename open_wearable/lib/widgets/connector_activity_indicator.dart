import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_wearable/models/connector_settings.dart';
import 'package:open_wearable/router.dart';
import 'package:open_wearable/widgets/connector_branding.dart';

/// Compact status pill shown while an external connector is active.
class ConnectorActivityIndicator extends StatelessWidget {
  const ConnectorActivityIndicator({
    super.key,
    this.statusListenable,
    this.onOpenSettings,
  });

  /// Runtime status source. Tests may inject a notifier without touching the
  /// process-wide connector service.
  final ValueListenable<ConnectorRuntimeStatus>? statusListenable;

  /// Opens connector settings. Defaults to navigating through the app router.
  final VoidCallback? onOpenSettings;

  ValueListenable<ConnectorRuntimeStatus> _resolveStatusListenable() {
    return statusListenable ??
        ConnectorSettings.webSocketRuntimeStatusListenable;
  }

  void _openSettings() {
    if (onOpenSettings != null) {
      onOpenSettings!();
      return;
    }

    rootNavigatorKey.currentContext?.push('/settings/connectors');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectorRuntimeStatus>(
      valueListenable: _resolveStatusListenable(),
      builder: (context, status, _) {
        if (!status.isActive) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;
        final foregroundColor =
            status.isHealthy ? const Color(0xFF1E6A3A) : colorScheme.error;
        final label = status.isHealthy
            ? 'Connector active'
            : 'Connector active, Wi-Fi unavailable';

        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 2),
          child: Tooltip(
            message: label,
            child: Semantics(
              button: true,
              label: label,
              liveRegion: true,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _openSettings,
                child: Container(
                  height: 32,
                  constraints: const BoxConstraints(minWidth: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: ShapeDecoration(
                    color: foregroundColor.withValues(alpha: 0.12),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: foregroundColor.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    ConnectorBranding.icon,
                    size: 16,
                    color: foregroundColor,
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
