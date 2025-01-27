import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class WearablesProvider with ChangeNotifier {
  final List<Wearable> _wearables = [];

  List<Wearable> get wearables => _wearables;

  void addWearable(Wearable wearable) {
    _wearables.add(wearable);
    wearable.addDisconnectListener(() {
      _wearables.remove(wearable);
      notifyListeners();
    });
    notifyListeners();
  }
}