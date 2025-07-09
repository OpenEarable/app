import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../../../view_models/sensor_configuration_provider.dart';
import '../../../view_models/sensor_configuration_storage.dart';

Logger _logger = Logger();

class SaveConfigRow extends StatefulWidget {
  const SaveConfigRow({super.key});

  @override
  State<SaveConfigRow> createState() => _SaveConfigRowState();
}

class _SaveConfigRowState extends State<SaveConfigRow> {
  String _configName = '';

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      title: PlatformTextField(
        onSubmitted: (value) async {
          setState(() {
            _configName = value;
          });
        },
      ),
      trailing: PlatformElevatedButton(
        onPressed: () async {
          SensorConfigurationProvider provider =
              Provider.of<SensorConfigurationProvider>(context, listen: false);
          Map<String, String> config = provider.toJson();

          _logger.d("Saving configuration: $_configName with data: $config");

          if (_configName.isNotEmpty) {
            await SensorConfigurationStorage.saveConfiguration(_configName, config);
          } else {
            showPlatformDialog(
              context: context,
              builder: (context) {
                return PlatformAlertDialog(
                  title: Text("Configuration Name Required"),
                  content: Text("Please enter a name for the configuration."),
                  actions: [
                    PlatformDialogAction(
                      child: PlatformText("OK"),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                );
              },
            );
          }
        },
        child: Text("Save"),
      ),
    );
  }
}
