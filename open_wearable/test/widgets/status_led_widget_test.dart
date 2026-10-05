import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/devices/device_detail/rgb_control.dart';
import 'package:open_wearable/widgets/devices/device_detail/status_led_widget.dart';

class TestLed implements StatusLed, RgbLed, LedStateReader {
  bool status = false;
  List<int> color = [0, 0, 0];
  bool failWrites = false;
  int reads = 0;

  @override
  Future<LedState> readLedState() async {
    reads++;
    return LedState(
      showStatus: status,
      red: color[0],
      green: color[1],
      blue: color[2],
    );
  }

  @override
  Future<void> showStatus(bool value) async {
    if (failWrites) throw StateError('Disconnected');
    status = value;
  }

  @override
  Future<void> writeLedColor(
      {required int r, required int g, required int b,}) async {
    if (failWrites) throw StateError('Disconnected');
    color = [r, g, b];
  }
}

void main() {
  Future<void> open(WidgetTester tester, TestLed led,
      {bool readback = true,}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatusLEDControlWidget(
      key: UniqueKey(),
      statusLED: led,
      rgbLed: led,
      stateReader: readback ? led : null,
    ),),),);
    await tester.pumpAndSettle();
  }

  List<bool> switches(WidgetTester tester) => tester
      .widgetList<Switch>(
        find.byType(Switch),
      )
      .map((s) => s.value)
      .toList();

  testWidgets('reopening restores disabled output and manual RGB',
      (tester) async {
    final led = TestLed();
    await open(tester, led);
    expect(switches(tester), [true, false]);
    led.color = [12, 34, 56];
    await open(tester, led);
    expect(switches(tester), [false, true]);
    expect(
        tester.widget<RgbControlView>(find.byType(RgbControlView)).initialColor,
        const Color.fromARGB(255, 12, 34, 56),);
    led.status = true;
    await open(tester, led);
    expect(switches(tester), [false, false]);
  });

  testWidgets('black override keeps the color picker usable until reopening',
      (tester) async {
    final led = TestLed()..status = true;
    await open(tester, led);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(switches(tester), [false, true]);
    expect(find.byType(RgbControlView), findsOneWidget);
    await open(tester, led);
    expect(switches(tester), [true, false]);
  });

  testWidgets('failed write retains confirmed state', (tester) async {
    final led = TestLed()..status = true;
    await open(tester, led);
    led.failWrites = true;
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(switches(tester), [false, false]);
  });

  testWidgets('older devices keep write controls without attempting readback',
      (tester) async {
    final led = TestLed()..status = true;
    await open(tester, led, readback: false);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(switches(tester), [true, false]);
    expect(led.reads, 0);
    expect(led.status, isFalse);
    expect(led.color, [0, 0, 0]);
  });
}
