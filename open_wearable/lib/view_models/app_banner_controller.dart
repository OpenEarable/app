import 'package:flutter/widgets.dart';
import 'package:open_wearable/widgets/app_banner.dart';

class AppBannerController with ChangeNotifier {
  List<AppBanner> activeBanners = [];

  Future<void> showBanner(AppBanner banner, Duration? duration) async {
    activeBanners.add(banner);
    if (duration != null) {
      Future.delayed(duration, () {
        hideBanner(banner);
      });
    }
    notifyListeners();
  }

  void hideBanner(AppBanner banner) {
    activeBanners.remove(banner);
    notifyListeners();
  }
}
