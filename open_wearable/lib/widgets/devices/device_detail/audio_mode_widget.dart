import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class AudioModeWidget extends StatefulWidget {
  final AudioModeManager device;

  const AudioModeWidget({
    super.key,
    required this.device,
  });

  @override
  State<AudioModeWidget> createState() => _AudioModeWidgetState();
}

class _AudioModeWidgetState extends State<AudioModeWidget> {
  AudioMode? _selectedAudioMode;

  @override
  void initState() {
    super.initState();
    _getSelectedAudioMode();
  }

  Future<void> _getSelectedAudioMode() async {
    final mode = await widget.device.getAudioMode();
    setState(() {
      _selectedAudioMode = mode;
    });
    }

  @override
  Widget build(BuildContext context) {
    return PlatformWidget(
      cupertino:(context, platform) => CupertinoSlidingSegmentedControl(
        children: {
          for (var item in widget.device.availableAudioModes)
            item : PlatformText(item.key),
        },
        onValueChanged: (AudioMode? mode) {
          if (mode == null) return;
          widget.device.setAudioMode(mode);
          setState(() {
            _selectedAudioMode = mode;
          });
        },
        groupValue: _selectedAudioMode,
      ),
      material: (context, platform) => SegmentedButton<AudioMode>(
        segments: 
          widget.device.availableAudioModes.map((item) {
            return ButtonSegment<AudioMode>(
              value: item,
              label: PlatformText(item.key),
            );
          }).toList(),
          onSelectionChanged: (Set<AudioMode> selected) {
            if (selected.isEmpty) return;
            widget.device.setAudioMode(selected.first);
            setState(() {
              _selectedAudioMode = selected.first;
            });
          },
          selected: _selectedAudioMode != null ? { _selectedAudioMode! } : {},
          emptySelectionAllowed: true,
        ),
    );
  }
}
