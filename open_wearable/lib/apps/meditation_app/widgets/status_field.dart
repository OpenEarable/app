import 'package:flutter/material.dart';
import '../model/service_connection_manager.dart';

class StatusField extends StatelessWidget {
  final Widget? neighbourWidget;
  final ConnectionManager connectionManager;

  /// The button's wording. A local model is prepared rather than connected to,
  /// so not every service this field reports on is reached over the network.
  final String actionLabel;

  const StatusField({
    super.key,
    this.neighbourWidget,
    required this.connectionManager,
    this.actionLabel = 'Check Connection',
  });

  Color get color {
    switch (connectionManager.status) {
      case ConnectionStatus.missing:
        return Colors.grey;
      case ConnectionStatus.checking:
        return Colors.blue;
      case ConnectionStatus.error:
        return Colors.red;
      case ConnectionStatus.ok:
        return Colors.green;
    }
  }

  String get statusText {
    switch (connectionManager.status) {
      case ConnectionStatus.missing:
        return "Not verified";
      case ConnectionStatus.checking:
        return "Checking...";
      case ConnectionStatus.error:
        return "Error";
      case ConnectionStatus.ok:
        return "OK";
    }
  }

  String get description {
    switch (connectionManager.status) {
      case ConnectionStatus.missing:
        return "Credentials have not been verified for the current settings.";
      case ConnectionStatus.checking:
        return "Checking the service connection. This may take a few seconds.";
      case ConnectionStatus.error:
        return connectionManager.lastError ??
            "The service check failed. Please review the credentials and region, then try again.";
      case ConnectionStatus.ok:
        return "The current credentials and settings were accepted.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        neighbourWidget ?? const SizedBox.shrink(),
        if (neighbourWidget != null) const SizedBox(height: 8),
        ListenableBuilder(
          listenable: connectionManager,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Current Source",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed:
                        connectionManager.status == ConnectionStatus.checking
                            ? null
                            : connectionManager.checkConnection,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
