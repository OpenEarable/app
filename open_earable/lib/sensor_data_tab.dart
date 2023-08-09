import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'dart:math';

class SensorDataTab extends StatefulWidget {
  @override
  _SensorDataTabState createState() => _SensorDataTabState();
}

class _SensorDataTabState extends State<SensorDataTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<charts.Series<dynamic, num>> seriesList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 4);
    _generateData(); // initial data generation
  }

  _generateData() {
    // Let's synthetically generate data for demo
    final random = new Random();
    final data = [
      // Generate synthetic data for 200 samples
      for (var i = 0; i < 50; i++) LinearData(i, random.nextInt(100) - 50, random.nextInt(100) - 50, random.nextInt(100) - 50)
    ];

    seriesList = [
      charts.Series<LinearData, int>(
        id: 'X',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (LinearData data, _) => data.index,
        measureFn: (LinearData data, _) => data.x,
        data: data,
      ),
      charts.Series<LinearData, int>(
        id: 'Y',
        colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
        domainFn: (LinearData data, _) => data.index,
        measureFn: (LinearData data, _) => data.y,
        data: data,
      ),
      charts.Series<LinearData, int>(
        id: 'Z',
        colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        domainFn: (LinearData data, _) => data.index,
        measureFn: (LinearData data, _) => data.z,
        data: data,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: PreferredSize(
    preferredSize: Size.fromHeight(kToolbarHeight), // Default AppBar height
    child: Container(
      color: Colors.brown,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white, // Color of the underline indicator
        labelColor: Colors.white,     // Color of the active tab label
        unselectedLabelColor: Colors.grey, // Color of the inactive tab labels
        tabs: [
          Tab(text: 'Accel.'),
          Tab(text: 'Gyro.'),
          Tab(text: 'Magnet.'),
          Tab(text: 'Pressure'),
        ],
      ),
    ),
  ),
  body: TabBarView(
    controller: _tabController,
    children: [
      _buildGraph('Accelerometer Data'),
      _buildGraph('Gyroscope Data'),
      _buildGraph('Magnetometer Data'),
      _buildGraph('Pressure Data'),
    ],
  ),
);
  }

  Widget _buildGraph(String title) {
    List<charts.Series<dynamic, num>> seriesForGraph;
  
    if (title == 'Pressure Data') {
      seriesForGraph = [seriesList[0]]; // Assuming the first series represents Pressure for this example
    } else {
      seriesForGraph = seriesList;
    }
  
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          // child: Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: charts.LineChart(
            seriesForGraph,
            animate: true,
             behaviors: [
              charts.SeriesLegend(
                position: charts.BehaviorPosition.bottom,  // To position the legend at the end (bottom). You can change this as per requirement.
                outsideJustification: charts.OutsideJustification.middleDrawArea,  // To justify the position.
                horizontalFirst: false,  // To stack items horizontally.
                desiredMaxRows: 1,  // Optional if you want to define max rows for the legend.
               entryTextStyle: charts.TextStyleSpec(  // Optional styling for the text.
                  color: charts.Color(r: 127, g: 63, b: 191),
                  fontSize: 12,
                ),
              )
            ],
            primaryMeasureAxis: charts.NumericAxisSpec(
              viewport: charts.NumericExtents(-100.0, 100.0),
            ),
          ),
        ),
      ],
    );
  }

}

class LinearData {
  final int index;
  final int x;
  final int y;
  final int z;

  LinearData(this.index, this.x, this.y, this.z);
}