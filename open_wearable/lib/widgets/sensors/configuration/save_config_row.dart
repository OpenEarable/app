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
        onChanged: (value) {
          setState(() {
            _configName = value;
          });
        },
        onSubmitted: (value) async {
          setState(() {
            _configName = value.trim();
          });
        },
        onTapOutside: (event) => FocusScope.of(context).unfocus(),
        hintText: "Save as...",
      ),
      trailing: PlatformElevatedButton(
        onPressed: () async {
          SensorConfigurationProvider provider =
              Provider.of<SensorConfigurationProvider>(context, listen: false);
          Map<String, String> config = provider.toJson();

          _logger.d("Saving configuration: $_configName with data: $config");

          if (_configName.isNotEmpty) {
            await SensorConfigurationStorage.saveConfiguration(_configName.trim(), config);
          } else {
            showPlatformDialog(
              context: context,
              builder: (context) {
                return PlatformAlertDialog(
                  title: PlatformText("Configuration Name Required"),
                  content: PlatformText("Please enter a name for the configuration."),
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
        child: PlatformText("Save"),
      ),
    );
  }
}
