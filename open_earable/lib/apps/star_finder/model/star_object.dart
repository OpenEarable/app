import 'dart:math';
import 'package:flutter/material.dart';

import 'package:open_earable/apps/star_finder/model/attitude.dart';

import 'dart:math';

class EulerAngle {
  double roll;  // Rotation sideways
  double pitch; // Rotation forward or backward
  double yaw;   // Rotation around the vertical axis

  EulerAngle(this.roll, this.pitch, this.yaw);
}
class StarObject {

  IconData icon;
  String name;
  String description;
  EulerAngle eulerAngle;
  String image;

  StarObject(this.icon, this.name, this.description, this.eulerAngle, this.image);

} 

class StarObjectList {
  static final List<StarObject> starObjects = [
    StarObject(Icons.hotel_class, "Little Dipper", "Known for the North Star.", EulerAngle(0.0, -40.0, 50.0),'assets/star_finder/little_dipper.png'),
    StarObject(Icons.hotel_class, "Orion", "Prominent constellation with a distinctive 'belt' of three stars.",
     calculateEulerAnglesForStar(CelestialCoordinates(5.60356, -1.20192), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/orion.png'),
    StarObject(Icons.hotel_class, "Big Dipper", "The most famous star constellation",
     calculateEulerAnglesForStar(CelestialCoordinates(11.03069, 6.38242), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/big_dipper.png'),
    StarObject(Icons.hotel_class, "Andromeda", "Features the closest spiral galaxy to the Milky Way.",
     calculateEulerAnglesForStar(CelestialCoordinates(1.16217, 3.62056), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/andromeda.png'),
    StarObject(Icons.hotel_class, "Gemini", "Twins constellation marked by two bright stars.",
     calculateEulerAnglesForStar(CelestialCoordinates(6.17053, 4.75461), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/gemini.png'),
    StarObject(Icons.hotel_class, "Cancer", "Faint zodiac constellation housing the Beehive Cluster.",
     calculateEulerAnglesForStar(CelestialCoordinates(8.97478, 1.50053), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/cancer.png'),
    StarObject(Icons.hotel_class, "Leo", "Resembles a lion, featuring the bright star Regulus.",
     calculateEulerAnglesForStar(CelestialCoordinates(10.33314, 9.84150), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/leo.png'),
    StarObject(Icons.hotel_class, "Cassiopeia", "W-shaped constellation, easily recognizable in the northern sky.",
     calculateEulerAnglesForStar(CelestialCoordinates(0.94514, 6.71667), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/cassiopeia.png'),
    
  ];
}

DateTime now = DateTime.now();
const double latitudeOfGermany = 51.0; // Approximate latitude for Germany
const double longitudeOfGermany = 10.0; // Approximate longitude for Germany

class CelestialCoordinates {
  double rightAscension; // in hours
  double declination;    // in degrees

  CelestialCoordinates(this.rightAscension, this.declination);
}

EulerAngle calculateEulerAnglesForStar(CelestialCoordinates starCoordinates, DateTime time, double latitude, double longitude) {
  // Convert current time to Julian Day
  double jd = timeToJulianDay(time);

  // Calculate Local Sidereal Time (LST)
  double lst = calculateLST(jd, longitude);

  // Convert Right Ascension to Hour Angle (in degrees)
  double hourAngle = 15 * (lst - starCoordinates.rightAscension);

  // Convert declination and observer's latitude to radians for calculations
  double decRad = starCoordinates.declination * pi / 180;
  double latRad = latitude * pi / 180;

  // Calculate altitude (pitch)
  double altitude = asin(sin(decRad) * sin(latRad) + cos(decRad) * cos(latRad) * cos(hourAngle * pi / 180));

  // Calculate azimuth (yaw)
  double azimuth = atan2(sin(hourAngle * pi / 180), 
                         cos(hourAngle * pi / 180) * sin(latRad) - tan(decRad) * cos(latRad));
  azimuth = azimuth < 0 ? azimuth + 2 * pi : azimuth;

  // Convert back to degrees
  altitude *= 180 / pi;
  azimuth *= 180 / pi;
  print("B,0,${altitude},${azimuth}");
  return EulerAngle(0, altitude, azimuth); // Assuming roll is 0
}

double timeToJulianDay(DateTime time) {
  int year = time.year;
  int month = time.month;
  double day = time.day +
               time.hour / 24.0 +
               time.minute / 1440.0 +
               time.second / 86400.0;

  if (month < 3) {
    year--;
    month += 12;
  }

  int A = year ~/ 100;
  int B = 2 - A + A ~/ 4;

  return (365.25 * (year + 4716)).floor() +
         (30.6001 * (month + 1)).floor() +
         day + B - 1524.5;
}

double calculateLST(double jd, double longitude) {
  double T = (jd - 2451545.0) / 36525.0; // Centuries from J2000.0
  double GMST = 280.46061837 + 360.98564736629 * (jd - 2451545) +
                T * T * 0.000387933 - T * T * T / 38710000.0;
  GMST = GMST % 360.0;
  double LST = GMST + longitude;
  if (LST < 0) LST += 360.0;
  return LST / 15.0; // Convert from degrees to hours
}

