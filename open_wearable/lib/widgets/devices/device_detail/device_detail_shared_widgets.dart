import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class ActionSurface extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const ActionSurface({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class DetailInfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  final Widget? trailing;
  final bool showDivider;

  const DetailInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ) ??
                          const TextStyle(),
                      child: value,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
          if (showDivider) ...[
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ],
        ],
      ),
    );
  }
}

class AsyncValueText extends StatelessWidget {
  final Future<Object?> future;

  const AsyncValueText({
    super.key,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<Object?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          );
        }

        final valueText =
            snapshot.hasError ? '--' : (snapshot.data?.toString() ?? '--');
        return Text(
          valueText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

class InlineLoading extends StatelessWidget {
  const InlineLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

class InlineHint extends StatelessWidget {
  final String text;

  const InlineHint({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class InlineError extends StatelessWidget {
  final String text;

  const InlineError({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class FirmwareTableUpdateHint extends StatelessWidget {
  final VoidCallback onTap;

  const FirmwareTableUpdateHint({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      icon: const Icon(
        Icons.system_update_alt_rounded,
        size: 15,
        color: Colors.white,
      ),
      label: Text(
        'Update',
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class FirmwareSupportIndicator extends StatelessWidget {
  final Future<FirmwareSupportStatus> supportFuture;

  const FirmwareSupportIndicator({
    super.key,
    required this.supportFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirmwareSupportStatus>(
      future: supportFuture,
      builder: (context, snapshot) {
        final support = snapshot.data;
        if (support == null || support == FirmwareSupportStatus.supported) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;

        IconData icon = Icons.help_rounded;
        Color color = colorScheme.onSurfaceVariant;
        String tooltip = 'Firmware support status is unknown';

        switch (support) {
          case FirmwareSupportStatus.tooOld:
            icon = Icons.warning_rounded;
            color = Colors.orange;
            tooltip = 'Firmware is too old';
            break;
          case FirmwareSupportStatus.tooNew:
            icon = Icons.warning_rounded;
            color = Colors.orange;
            tooltip = 'Firmware is newer than supported';
            break;
          case FirmwareSupportStatus.unknown:
            icon = Icons.help_rounded;
            color = colorScheme.onSurfaceVariant;
            tooltip = 'Firmware support is unknown';
            break;
          case FirmwareSupportStatus.unsupported:
            icon = Icons.error_outline_rounded;
            color = colorScheme.error;
            tooltip = 'Firmware is unsupported';
            break;
          case FirmwareSupportStatus.supported:
            return const SizedBox.shrink();
        }

        return Tooltip(
          message: tooltip,
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        );
      },
    );
  }
}
