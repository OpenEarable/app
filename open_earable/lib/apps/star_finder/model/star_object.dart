import 'dart:math';
import 'package:flutter/material.dart';

import 'package:open_earable/apps/star_finder/model/attitude.dart';

class StarObject {

  IconData icon;
  String name;
  String description;
  double x;
  double y;
  double z;

  StarObject(this.icon, this.name, this.description, this.x, this.y, this.z);

  /// The vales detected from the magnetometer vary for each variable
  /// x = around -200 to 600 => 800 range
  /// y = around -100 to 60  => 160 range
  /// z = around -300 to 300 => 600 range
  /// Right direction set to be (-)5% of exact right direction
  bool inThisDirection(Attitude attitude) {
    double distanceX = (attitude.x - x).abs();
    double distanceY = (attitude.y - y).abs();
    double distanceZ = (attitude.z - z).abs();
    return distanceX < 40.0 && distanceY < 8.0 && distanceZ < 30.0;

  }

} 

class StarObjectList {
  static final List<StarObject> starObjects = [
    StarObject(Icons.star, "Polaris", "Also known as North Star or Pole Star", 392.0, -40.0, -288.0),
    StarObject(Icons.hotel_class, "Little Bear", "Well known small constellation", 392.0, -40.0, -288.0),
    StarObject(Icons.hotel_class, "Big Bear", "Well known small constellation", 392.0, -40.0, -288.0)
  ];
}
