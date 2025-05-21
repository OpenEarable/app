import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firmware_select/firmware_list.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class FirmwareSelect extends StatelessWidget {
  const FirmwareSelect({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    FirmwareUpdateRequest updateParameters =
        context.watch<FirmwareUpdateRequestProvider>().updateParameters;

    return Column(
      children: [
        if (updateParameters.firmware != null)
          Text(updateParameters.firmware!.name),
        ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FirmwareList()),
              );
            },
            child: Text('Select Firmware')),
      ],
    );
  }
}
