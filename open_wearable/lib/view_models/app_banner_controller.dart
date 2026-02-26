import 'package:flutter/material.dart';

import '../widgets/app_banner.dart';

/// Manages transient in-app banners shown in the global overlay.
///
/// Needs:
/// - Banner widgets constructed by callers.
///
/// Does:
/// - Inserts/removes active banners and handles optional auto-dismiss.
///
/// Provides:
/// - A `ChangeNotifier` list (`activeBanners`) consumed by the overlay widget.
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
