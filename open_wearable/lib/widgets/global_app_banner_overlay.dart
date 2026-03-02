import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/app_banner_controller.dart';

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
        final hasBanners = banners.isNotEmpty;

        // Use existing Directionality if present, otherwise default to LTR
        final textDirection =
            Directionality.maybeOf(context) ?? TextDirection.ltr;

        return Directionality(
          textDirection: textDirection,
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              child,
              if (hasBanners)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          for (final banner in banners)
                            Padding(
                              padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                              key: banner.key,
                              child: banner,
                            ),
                        ],
                      ),
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
