import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/app_banner_controller.dart';
import '../view_models/bluetooth_availability_provider.dart';

class GlobalAppBannerOverlay extends StatelessWidget {
  final Widget child;

  const GlobalAppBannerOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppBannerController, BluetoothAvailabilityProvider>(
      builder: (context, controller, bluetoothAvailability, _) {
        final banners = controller.activeBanners;
        final hasBanners = banners.isNotEmpty;
        final showBluetoothWarning = bluetoothAvailability.isPoweredOff;
        final hasOverlay = hasBanners || showBluetoothWarning;

        // Use existing Directionality if present, otherwise default to LTR
        final textDirection =
            Directionality.maybeOf(context) ?? TextDirection.ltr;

        return Directionality(
          textDirection: textDirection,
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              child,
              if (hasOverlay)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showBluetoothWarning)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
                            child: _BluetoothDisabledBanner(),
                          ),
                        if (hasBanners)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                for (final banner in banners)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    key: banner.key,
                                    child: banner,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BluetoothDisabledBanner extends StatelessWidget {
  const _BluetoothDisabledBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.errorContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bluetooth is off. Turn it on to scan and connect devices.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
