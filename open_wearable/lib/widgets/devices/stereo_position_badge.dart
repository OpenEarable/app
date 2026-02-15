import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/devices/device_status_pills.dart';

class StereoPositionBadge extends StatefulWidget {
  final StereoDevice device;

  const StereoPositionBadge({super.key, required this.device});

  @override
  State<StereoPositionBadge> createState() => _StereoPositionBadgeState();
}

class _StereoPositionBadgeState extends State<StereoPositionBadge> {
  static final Expando<Future<DevicePosition?>> _positionFutureCache =
      Expando<Future<DevicePosition?>>();

  late Future<DevicePosition?> _positionFuture;

  @override
  void initState() {
    super.initState();
    _positionFuture = _resolvePositionFuture(widget.device);
  }

  @override
  void didUpdateWidget(covariant StereoPositionBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _positionFuture = _resolvePositionFuture(widget.device);
    }
  }

  Future<DevicePosition?> _resolvePositionFuture(StereoDevice device) {
    return _positionFutureCache[device] ??= device.position;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DevicePosition?>(
      future: _positionFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final label = switch (snapshot.data) {
          DevicePosition.left => 'L',
          DevicePosition.right => 'R',
          _ => null,
        };

        if (!isLoading && label == null) {
          return const SizedBox.shrink();
        }

        return DeviceMetadataBubble(
          label: isLoading ? '...' : (label ?? '--'),
          highlighted: true,
        );
      },
    );
  }
}
