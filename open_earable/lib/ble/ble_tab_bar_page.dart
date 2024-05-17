import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_connect_view.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/ble/ble_controller.dart';

class BLETabBarPage extends StatefulWidget {
  final int index;
  BLETabBarPage({int this.index = 0});

  @override
  _BLETabBarPageState createState() => _BLETabBarPageState();
}

class _BLETabBarPageState extends State<BLETabBarPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CupertinoTabController _cupertinoTabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = widget.index;
    _cupertinoTabController =
        CupertinoTabController(initialIndex: widget.index);
    _tabController.addListener(_handleTabChange);
    _cupertinoTabController.addListener(_handleTabChangeCupertino);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 0) {
        Provider.of<BluetoothController>(context, listen: false).startScanning(
            Provider.of<BluetoothController>(context, listen: false)
                .openEarableLeft);
      } else if (_tabController.index == 1) {
        Provider.of<BluetoothController>(context, listen: false).startScanning(
            Provider.of<BluetoothController>(context, listen: false)
                .openEarableRight);
      }
    }
  }

  void _handleTabChangeCupertino() {
    if (_cupertinoTabController.index == 0) {
      Provider.of<BluetoothController>(context, listen: false).startScanning(
          Provider.of<BluetoothController>(context, listen: false)
              .openEarableLeft);
    } else if (_cupertinoTabController.index == 1) {
      Provider.of<BluetoothController>(context, listen: false).startScanning(
          Provider.of<BluetoothController>(context, listen: false)
              .openEarableRight);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _cupertinoTabController.removeListener(_handleTabChangeCupertino);
    _cupertinoTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS
        ? CupertinoPageScaffold(
            backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
            navigationBar: CupertinoNavigationBar(
              middle: Text("Bluetooth Devices"),
              leading: CupertinoNavigationBarBackButton(
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            child: CupertinoTabScaffold(
              controller: _cupertinoTabController,
              tabBar: CupertinoTabBar(
                items: [
                  BottomNavigationBarItem(
                    label: 'Left Earable',
                    icon: ImageIcon(
                        AssetImage('assets/OpenEarableIconLeft.png'),
                        size: 40.0),
                  ),
                  BottomNavigationBarItem(
                    label: 'Right Earable',
                    icon: ImageIcon(
                      AssetImage('assets/OpenEarableIconRight.png'),
                      size: 40.0,
                    ),
                  ),
                ],
              ),
              tabBuilder: (BuildContext context, int index) {
                return CupertinoTabView(
                  builder: (context) {
                    return index == 0
                        ? BLEPage(
                            Provider.of<BluetoothController>(context)
                                .openEarableLeft,
                            0)
                        : BLEPage(
                            Provider.of<BluetoothController>(context)
                                .openEarableRight,
                            1);
                  },
                );
              },
            ))
        : Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            appBar: AppBar(
              title: Text("Bluetooth Devices"),
            ),
            body: DefaultTabController(
              length: 2,
              child: Scaffold(
                backgroundColor: Theme.of(context).colorScheme.background,
                body: TabBarView(
                  controller: _tabController,
                  physics:
                      NeverScrollableScrollPhysics(), // Disable swipe to change tabs
                  children: [
                    BLEPage(
                        Provider.of<BluetoothController>(context)
                            .openEarableLeft,
                        0),
                    BLEPage(
                        Provider.of<BluetoothController>(context)
                            .openEarableRight,
                        1),
                  ],
                ),
                bottomNavigationBar: BottomNavigationBar(
                  backgroundColor: Theme.of(context).colorScheme.background,
                  currentIndex: _tabController.index,
                  onTap: (index) {
                    setState(() {
                      _tabController.index = index;
                    });
                  },
                  items: [
                    BottomNavigationBarItem(
                      label: 'Left Earable',
                      icon: ImageIcon(
                        AssetImage('assets/OpenEarableIconLeft.png'),
                        size: 40.0,
                      ),
                    ),
                    BottomNavigationBarItem(
                      label: 'Right Earable',
                      icon: ImageIcon(
                        AssetImage('assets/OpenEarableIconRight.png'),
                        size: 40.0,
                      ),
                    ),
                  ],
                ),
              ),
            ));
  }
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothController()),
      ],
      child: MaterialApp(
        home: BLETabBarPage(),
      ),
    ),
  );
}
