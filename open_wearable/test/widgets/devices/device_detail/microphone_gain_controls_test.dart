import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/devices/device_detail/microphone_gain_controls.dart';

void main() {
  testWidgets('reset restores the documented default gain', (tester) async {
    final manager = _FakeMicrophoneGainManager(
      const MicrophoneGain.muted(),
    );
    final wearable = _FakeWearable(manager, deviceId: 'single-device');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrophoneGainControls(device: wearable),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Default:'), findsNothing);
    expect(find.text('Adjust inner and outer mic levels.'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.text('Muted'), findsNWidgets(2));
    final unmuteButtonFinder = find.widgetWithText(FilledButton, 'Unmute');
    final unmuteButton = tester.widget<FilledButton>(unmuteButtonFinder);
    expect(
      unmuteButton.style?.backgroundColor?.resolve({}),
      Theme.of(tester.element(unmuteButtonFinder)).colorScheme.errorContainer,
    );

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(manager.writes, hasLength(1));
    expect(
      manager.writes.single.outerRegister,
      MicrophoneGain.defaultRegister,
    );
    expect(
      manager.writes.single.innerRegister,
      MicrophoneGain.defaultRegister,
    );
    expect(find.text('+12 dB'), findsNWidgets(2));
    final muteButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mute'),
    );
    expect(muteButton.style?.backgroundColor?.resolve({}), Colors.transparent);
  });

  testWidgets('stereo layout keeps heading outside the controls card', (
    tester,
  ) async {
    final left = _FakeWearable(
      _FakeMicrophoneGainManager(
        const MicrophoneGain.stereo(MicrophoneGain.defaultRegister),
      ),
      deviceId: 'left-device',
    );
    final right = _FakeWearable(
      _FakeMicrophoneGainManager(
        const MicrophoneGain.stereo(MicrophoneGain.defaultRegister),
      ),
      deviceId: 'right-device',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrophoneGainControls(
            device: left,
            pairedDevice: right,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controlsCard = find.byType(Card);
    expect(controlsCard, findsOneWidget);
    expect(
      find.descendant(
        of: controlsCard,
        matching: find.text('Microphone Gain'),
      ),
      findsNothing,
    );
    for (final label in ['Reset', 'Mute']) {
      expect(
        find.descendant(of: controlsCard, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      tester
          .widget<Padding>(
            find.byKey(const Key('microphone-gain-controls-padding')),
          )
          .padding,
      const EdgeInsets.all(12),
    );
    expect(
      find.descendant(of: controlsCard, matching: find.byType(Divider)),
      findsNothing,
    );
    final linkControl = find.byKey(
      const Key('microphone-gain-link-control'),
    );
    expect(linkControl, findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(
      tester
          .getSize(
            find.byKey(const Key('microphone-gain-row-spacing')),
          )
          .height,
      4,
    );

    final actionY = [
      tester.getCenter(find.text('Reset')).dy,
      tester.getCenter(find.text('Mute')).dy,
    ];
    expect(actionY.toSet(), hasLength(1));
    expect(
      tester.getCenter(find.text('Reset')).dx,
      lessThan(tester.getCenter(find.text('Mute')).dx),
    );
    final resetButton = find.widgetWithText(OutlinedButton, 'Reset');
    final muteButton = find.widgetWithText(FilledButton, 'Mute');
    expect(
      tester.getSize(resetButton).width,
      closeTo(tester.getSize(muteButton).width, 0.1),
    );
    expect(tester.getSize(resetButton).height, 48);
    expect(tester.getSize(muteButton).height, 48);

    final outerY = tester.getCenter(find.text('Outer')).dy;
    final sliderY = tester.getCenter(find.byType(Slider).first).dy;
    final valueY = tester.getCenter(find.text('+12 dB').first).dy;
    expect(outerY, closeTo(sliderY, 0.1));
    expect(valueY, closeTo(sliderY, 0.1));
    final sliderTheme = tester.widget<SliderTheme>(
      find.ancestor(
        of: find.byType(Slider).first,
        matching: find.byType(SliderTheme),
      ),
    );
    expect(
      sliderTheme.data.padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    );
    final connectorCenter = tester.getCenter(linkControl);
    expect(
      connectorCenter.dx,
      lessThan(tester.getCenter(find.text('Outer')).dx),
    );
    expect(
      connectorCenter.dy,
      greaterThan(tester.getCenter(find.text('Outer')).dy),
    );
    expect(
      connectorCenter.dy,
      lessThan(tester.getCenter(find.text('Inner')).dy),
    );
    expect(
      tester.getCenter(find.text('Reset')).dy,
      greaterThan(tester.getCenter(find.byType(Slider).last).dy),
    );
  });

  testWidgets('both sliders stay active while linked and after unlinking', (
    tester,
  ) async {
    final manager = _FakeMicrophoneGainManager(
      const MicrophoneGain.stereo(MicrophoneGain.defaultRegister),
    );
    final wearable = _FakeWearable(
      manager,
      deviceId: 'single-device',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrophoneGainControls(device: wearable),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.link_rounded)).color,
      const Color(0xFF2E7D32),
    );
    final linkSurfaceFinder = find.byKey(
      const Key('microphone-gain-link-button-surface'),
    );
    final linkSurface = tester.widget<Material>(linkSurfaceFinder);
    final colorScheme = Theme.of(tester.element(linkSurfaceFinder)).colorScheme;
    expect(linkSurface.color?.a, 1.0);
    expect(
      linkSurface.color,
      Color.alphaBlend(
        const Color(0xFF2E7D32).withValues(alpha: 0.12),
        colorScheme.surface,
      ),
    );
    expect(
      tester.widget<Slider>(find.byType(Slider).first).onChanged,
      isNotNull,
    );
    final linkedInnerSlider = tester.widget<Slider>(find.byType(Slider).last);
    expect(linkedInnerSlider.onChanged, isNotNull);

    linkedInnerSlider.onChanged!(0);
    await tester.pump();

    expect(find.text('0 dB'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const Key('microphone-gain-link-control')),
    );
    await tester.pump();

    expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
    expect(
      tester.widget<Slider>(find.byType(Slider).last).onChanged,
      isNotNull,
    );
  });

  testWidgets('out-of-sync warning has no sync action or confirmation', (
    tester,
  ) async {
    final leftManager = _FakeMicrophoneGainManager(
      const MicrophoneGain.stereo(MicrophoneGain.defaultRegister),
    );
    final rightManager = _FakeMicrophoneGainManager(
      const MicrophoneGain.stereo(MicrophoneGain.zeroDbRegister),
    );
    final left = _FakeWearable(leftManager, deviceId: 'left-device');
    final right = _FakeWearable(rightManager, deviceId: 'right-device');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrophoneGainControls(
            device: left,
            pairedDevice: right,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Left and right gains differ'), findsOneWidget);
    expect(find.text('Sync'), findsNothing);
    final warningFinder = find.byKey(
      const Key('microphone-gain-mismatch-warning'),
    );
    final warning = tester.widget<Container>(warningFinder);
    final warningDecoration = warning.decoration! as BoxDecoration;
    final errorColor =
        Theme.of(tester.element(warningFinder)).colorScheme.error;
    expect(warningDecoration.color, errorColor.withValues(alpha: 0.10));
    expect(
      warningDecoration.border,
      Border.all(color: errorColor.withValues(alpha: 0.38)),
    );
    expect(leftManager.writes, isEmpty);
    expect(rightManager.writes, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}

class _FakeMicrophoneGainManager implements MicrophoneGainManager {
  _FakeMicrophoneGainManager(this.currentGain);

  MicrophoneGain currentGain;
  final List<MicrophoneGain> writes = [];

  @override
  Future<MicrophoneGain> getMicrophoneGain() async => currentGain;

  @override
  Future<void> setMicrophoneGain(MicrophoneGain gain) async {
    currentGain = gain;
    writes.add(gain);
  }
}

class _FakeWearable extends Wearable {
  _FakeWearable(
    MicrophoneGainManager manager, {
    required this.deviceId,
  }) : super(
          name: 'OpenEarable-2-L',
          disconnectNotifier: WearableDisconnectNotifier(),
        ) {
    registerCapability<MicrophoneGainManager>(manager);
  }

  @override
  final String deviceId;

  @override
  Future<void> disconnect() async {}
}
