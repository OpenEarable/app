String createDate(int dt, String type) {
  DateTime day = DateTime.fromMillisecondsSinceEpoch(dt);
  if (type == "long") {
    return "${day.weekdayToString}, ${day.day} ${day.monthToString} ${day.year}";
  } else {
    return day.weekdayToString;
  }
}

extension DateExtension on DateTime {
  String get weekdayToString {
    List<String> weekdays = [
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ];
    return weekdays[this.weekday - 1];
  }

  String get monthToString {
    List<String> months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return months[this.month - 1];
  }
}
