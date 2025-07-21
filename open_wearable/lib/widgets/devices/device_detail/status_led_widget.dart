import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'rgb_control.dart';

// MARK: - Status LED Widget
class StatusLEDControlWidget extends StatefulWidget {
  final StatusLed statusLED;
  final RgbLed rgbLed;
  const StatusLEDControlWidget({super.key, required this.statusLED, required this.rgbLed});

  @override
  State<StatusLEDControlWidget> createState() => _StatusLEDControlWidgetState();
}

class _StatusLEDControlWidgetState extends State<StatusLEDControlWidget> {
  bool _overrideColor = false;

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      title: PlatformText("Override LED Color", style: Theme.of(context).textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_overrideColor)
            RgbControlView(rgbLed: widget.rgbLed),
          PlatformSwitch(
            value: _overrideColor,
            onChanged: (value) async {
              setState(() {
                _overrideColor = value;
              });
              widget.statusLED.showStatus(!value);
            },
          ),
        ],
      ),
    );
  }
}
