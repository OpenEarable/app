import 'dart:math';

/// Class storing the Euler Angles
class EulerAngle {
  double roll;  // Rotation sideways
  double pitch; // Rotation forward or backward
  double yaw;   // Rotation around the vertical axis

  EulerAngle(this.roll, this.pitch, this.yaw);
}

 // Class represents a star or celestial object in the sky.
class StarObject {
  String name; // Name of the Star Object
  String description; // Description of the Star Object
  EulerAngle eulerAngle; // Euler Angle of the Star Object
  String image; // Image of the Star Object

  StarObject(this.name, this.description, this.eulerAngle, this.image);

} 

/// List of Star constellations and their data
class StarObjectList {
  static final List<StarObject> starObjects = [
    // The Little Dipper doesn't move on the nightsky, so his Euler Angles are still the same
    StarObject("Little Dipper", "The Little Dipper is well-known, notable for containing the North Star", EulerAngle(0.0, -40.0, 50.0),'assets/star_finder/little_dipper.png'),
    StarObject("Orion", "Prominent constellation with a distinctive 'belt' of three stars",
     calculateEulerAnglesForStar(CelestialCoordinates(5.60356, -1.20192), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/orion.png'),
    StarObject("Big Dipper", "The Big Dipper is well-known, resembling a large ladle with seven bright stars",
     calculateEulerAnglesForStar(CelestialCoordinates(11.03069, 6.38242), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/big_dipper.png'),
    StarObject("Cancer", "Faint zodiac constellation housing the Beehive Cluster",
     calculateEulerAnglesForStar(CelestialCoordinates(8.97478, 1.50053), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/cancer.png'),
    StarObject("Leo", "Resembles a lion, featuring the bright star Regulus",
     calculateEulerAnglesForStar(CelestialCoordinates(10.33314, 9.84150), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/leo.png'),
    StarObject("Cassiopeia", "W-shaped constellation, easily recognizable in the northern sky",
     calculateEulerAnglesForStar(CelestialCoordinates(0.94514, 6.71667), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/cassiopeia.png'),
     StarObject("Gemini", "Twins constellation marked by two bright stars",
    calculateEulerAnglesForStar(CelestialCoordinates(6.17053, 4.75461), now, latitudeOfGermany, longitudeOfGermany), 'assets/star_finder/gemini.png'),
    
  ];
}

DateTime now = DateTime.now(); // Time opening the App
const double latitudeOfGermany = 51.0; // Approximate latitude for Germany
const double longitudeOfGermany = 10.0; // Approximate longitude for Germany

/// Celestial coordinates are used in astronomy to specify the position of objects in the sky.
/// This class uses the equatorial coordinate system, which is the standard coordinate system for mapping stars and other celestial bodies.
class CelestialCoordinates {
  double rightAscension; // in hours
  double declination;    // in degrees

  CelestialCoordinates(this.rightAscension, this.declination);
}

/// Calculates actual Euler Angles depending on time, location and Celestial Coordinates
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

/// The Julian Day is a continuous count of days since the beginning of the Julian Period.
/// It's used in astronomical calculations as a time standard.
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

/// Calculates Local Sidereal Time (LST) based on Julian Day and longitude.
/// Sidereal Time is used in astronomy to keep track of the direction to observe stars. 
/// It's based on Earth's rate of rotation measured relative to the fixed stars.
double calculateLST(double jd, double longitude) {
  double T = (jd - 2451545.0) / 36525.0; // Centuries from J2000.0
  double GMST = 280.46061837 + 360.98564736629 * (jd - 2451545) +
                T * T * 0.000387933 - T * T * T / 38710000.0;
  GMST = GMST % 360.0;
  double LST = GMST + longitude;
  if (LST < 0) LST += 360.0;
  return LST / 15.0; // Convert from degrees to hours
}

