import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/fota/fota_slots_page.dart';

class _Ear extends Wearable implements FotaSlotInfoCapability {
  _Ear(this.image)
      : super(
          name: 'OpenEarable',
          disconnectNotifier: WearableDisconnectNotifier(),
        );

  final int image;
  final erasedChannels = <int?>[];

  @override
  String get deviceId => 'ear';

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<FirmwareSlotInfo>> readFirmwareSlots() async => [
        FirmwareSlotInfo(
          image: image,
          slot: 1,
          version: '2.3.0',
          hash: const [1],
          hashString: '01',
          bootable: true,
          pending: false,
          confirmed: false,
          active: false,
          permanent: false,
        ),
      ];

  @override
  Future<void> eraseFirmwareSlot({int? channel}) async {
    erasedChannels.add(channel);
  }
}

void main() {
  for (final (image, channel) in [(0, 1), (1, 3), (2, 5)]) {
    testWidgets('erasing image $image targets secondary channel $channel',
        (tester) async {
      final ear = _Ear(image);
      await tester.pumpWidget(MaterialApp(home: FotaSlotsPage(device: ear)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Erase slot'));
      await tester.tap(find.text('Erase slot'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This erases image $image, slot 1'),
        findsOneWidget,
      );
      expect(ear.erasedChannels, isEmpty);
      await tester.tap(find.text('Erase'));
      await tester.pumpAndSettle();

      expect(ear.erasedChannels, [channel]);
    });
  }
}
