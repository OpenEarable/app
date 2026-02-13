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
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 6),
                        ...banners.map(
                          (banner) => Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                            child: Dismissible(
                              key: banner.key ?? UniqueKey(),
                              direction: DismissDirection.up,
                              onDismissed: (_) => controller.hideBanner(banner),
                              child: banner,
                            ),
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
