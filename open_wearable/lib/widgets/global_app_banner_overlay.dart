import 'package:flutter/material.dart';
import 'package:open_wearable/view_models/app_banner_controller.dart';
import 'package:provider/provider.dart';

class GlobalAppBannerOverlay extends StatelessWidget {
  final Widget child;

  const GlobalAppBannerOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppBannerController>(
      builder: (context, controller, _) {
        final banners = controller.activeBanners;

        // Use existing Directionality if present, otherwise default to LTR
        final textDirection =
            Directionality.maybeOf(context) ?? TextDirection.ltr;

        return Directionality(
          textDirection: textDirection,
          child: Stack(
            alignment: Alignment.topLeft, // non-directional
            children: [
              child,
              if (banners.isNotEmpty)
                Positioned(
                  // show below the status bar / notch
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        for (final banner in banners)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: banner, // AppBanner is already a complete view
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
