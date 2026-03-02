import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class MicrophoneSelectionWidget extends StatefulWidget {
  final MicrophoneManager device;

  const MicrophoneSelectionWidget({
    super.key,
    required this.device,
  });

  @override
  State<MicrophoneSelectionWidget> createState() => _MicrophoneSelectionWidgetState();
}

class _MicrophoneSelectionWidgetState extends State<MicrophoneSelectionWidget> {
  Microphone? _selectedMicrophone;

  @override
  void initState() {
    super.initState();
    _getSelectedMicrophone();
  }

  Future<void> _getSelectedMicrophone() async {
    final mode = await widget.device.getMicrophone();
    setState(() {
      _selectedMicrophone = mode;
    });
    }

  @override
  Widget build(BuildContext context) {
    return PlatformWidget(
      cupertino:(context, platform) => CupertinoSlidingSegmentedControl(
        children: {
          for (var item in widget.device.availableMicrophones)
            item : PlatformText(item.key),
        },
        onValueChanged: (Microphone? mode) {
          if (mode == null) return;
          widget.device.setMicrophone(mode);
          setState(() {
            _selectedMicrophone = mode;
          });
        },
        groupValue: _selectedMicrophone,
      ),
      material: (context, platform) => SegmentedButton<Microphone>(
        segments: 
          widget.device.availableMicrophones.map((item) {
            return ButtonSegment<Microphone>(
              value: item,
              label: PlatformText(item.key),
            );
          }).toList(),
          onSelectionChanged: (Set<Microphone> selected) {
            if (selected.isEmpty) return;
            widget.device.setMicrophone(selected.first);
            setState(() {
              _selectedMicrophone = selected.first;
            });
          },
          selected: _selectedMicrophone != null ? { _selectedMicrophone! } : {},
          emptySelectionAllowed: true,
        ),
    );
  }
}
