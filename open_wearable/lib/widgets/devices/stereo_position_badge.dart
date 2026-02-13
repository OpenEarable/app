import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class StereoPositionBadge extends StatefulWidget {
  final StereoDevice device;

  const StereoPositionBadge({super.key, required this.device});

  @override
  State<StereoPositionBadge> createState() => _StereoPositionBadgeState();
}

class _StereoPositionBadgeState extends State<StereoPositionBadge> {
  late Future<DevicePosition?> _positionFuture;

  @override
  void initState() {
    super.initState();
    _positionFuture = widget.device.position;
  }

  @override
  void didUpdateWidget(covariant StereoPositionBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _positionFuture = widget.device.position;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DevicePosition?>(
      future: _positionFuture,
      builder: (context, snapshot) {
        final foregroundColor = Theme.of(context).colorScheme.primary;
        final backgroundColor = foregroundColor.withValues(alpha: 0.12);
        final borderColor = foregroundColor.withValues(alpha: 0.24);

        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final label = switch (snapshot.data) {
          DevicePosition.left => 'L',
          DevicePosition.right => 'R',
          _ => null,
        };

        if (!isLoading && label == null) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                ),
              if (isLoading) const SizedBox(width: 6),
              Text(
                label ?? '--',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
