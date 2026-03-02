import 'package:flutter/material.dart';

import '../widgets/app_banner.dart';

class AppBannerController with ChangeNotifier {
  final List<AppBanner> activeBanners = [];
  int _nextId = 0;

  int showBanner(AppBanner Function(int id) builder, {Duration? duration}) {
    final id = _nextId++;
    final banner = builder(id);
    activeBanners.insert(0, banner);

    if (duration != null) {
      Future.delayed(duration, () {
        hideBanner(banner);
      });
    }

    notifyListeners();
    return id;
  }

  void hideBanner(AppBanner banner) {
    final removed = activeBanners.remove(banner);
    if (!removed) {
      return;
    }
    notifyListeners();
  }

  void hideBannerByKey(Key key) {
    final before = activeBanners.length;
    activeBanners.removeWhere((b) => b.key == key);
    if (activeBanners.length == before) {
      return;
    }
    notifyListeners();
  }
}
