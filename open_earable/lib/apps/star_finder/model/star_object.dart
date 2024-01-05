import 'dart:math';

import 'package:open_earable/apps/star_finder/model/attitude.dart';

class StarObject {
  double x;
  double y;
  double z;

  StarObject(this.x, this.y, this.z);

  double calculateDistance(double x1, double y1, double z1) {
    double distance = sqrt(pow(this.x - x1, 2) + pow(this.y - y1, 2) + pow(this.z - z1, 2));
    return distance;
}
}