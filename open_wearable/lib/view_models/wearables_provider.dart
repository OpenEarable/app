import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

class WearablesProvider with ChangeNotifier {
  final List<Wearable> _wearables = [];
  final Map<Wearable, SensorConfigurationProvider> _sensorConfigurationProviders = {};

  List<Wearable> get wearables => _wearables;
  Map<Wearable, SensorConfigurationProvider> get sensorConfigurationProviders => _sensorConfigurationProviders;

  void addWearable(Wearable wearable) async {
    // ignore all wearables that are already added
    if (_wearables.any((w) => w.deviceId == wearable.deviceId)) {
      return;
    }

    _wearables.add(wearable);
    if (wearable is SensorConfigurationManager) {
      if (!_sensorConfigurationProviders.containsKey(wearable)) {
        _sensorConfigurationProviders[wearable] = SensorConfigurationProvider(
          sensorConfigurationManager: wearable as SensorConfigurationManager,
        );
      }

      SensorConfigurationProvider notifier = _sensorConfigurationProviders[wearable]!;
      for (SensorConfiguration config in (wearable as SensorConfigurationManager).sensorConfigurations) {
        if (notifier.getSelectedConfigurationValue(config) == null) {
          notifier.addSensorConfiguration(config, config.values.first);
        }
      }
    }
    wearable.addDisconnectListener(() {
      removeWearable(wearable);
      notifyListeners();
    });

    if (wearable is StereoDevice) {
      if (await (wearable as StereoDevice).pairedDevice == null) {
        List<StereoDevice> possiblePairs =
          await WearableManager().findValidPairsFor((wearable as StereoDevice), _wearables.whereType<StereoDevice>().toList());

        logger.d("possible pairs: $possiblePairs");

        if (possiblePairs.isNotEmpty) {
          (wearable as StereoDevice).pair(possiblePairs.first);
          logger.i("Paired ${wearable.name} with ${(wearable as StereoDevice).pairedDevice}");
        }
      }
    }
    
    notifyListeners();
  }

  void removeWearable(Wearable wearable) {
    _wearables.remove(wearable);
    _sensorConfigurationProviders.remove(wearable);
    notifyListeners();
  }

  SensorConfigurationProvider getSensorConfigurationProvider(Wearable wearable) {
    if (!_sensorConfigurationProviders.containsKey(wearable)) {
      throw Exception('No SensorConfigurationProvider found for the given wearable: ${wearable.name}');
    }
    return _sensorConfigurationProviders[wearable]!;
  }
}
