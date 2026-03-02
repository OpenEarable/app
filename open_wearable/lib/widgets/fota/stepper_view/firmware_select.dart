import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';

import '../firmware_select/firmware_list.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class FirmwareSelect extends StatelessWidget {
  const FirmwareSelect({super.key});

  @override
  Widget build(BuildContext context) {
    FirmwareUpdateRequest updateParameters =
        context.watch<FirmwareUpdateRequestProvider>().updateParameters;

    return Column(
      children: [
        if (updateParameters.firmware != null)
          PlatformText(updateParameters.firmware!.name),
        PlatformElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FirmwareList(),
              ),
            );
          },
          child: PlatformText('Select Firmware'),
        ),
      ],
    );
  }
}
