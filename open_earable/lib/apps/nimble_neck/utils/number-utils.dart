/// Converts a given Integer [number] to a String
/// Prepends '0' if [number] is lower than 10
String leadingZeroToDigit(int number) => "${number < 10 ? '0' : ''}$number";
