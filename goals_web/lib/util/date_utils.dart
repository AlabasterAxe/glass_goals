import 'package:goals_core/sync.dart' show StatusLogEntry;
import 'package:intl/intl.dart' show DateFormat;

formatDate(DateTime date) {
  return DateFormat('yyyy.MM.dd.').format(date) +
      DateFormat('EE').format(date).substring(0, 2).toUpperCase();
}

_statusIsBetweenDates(StatusLogEntry status, DateTime start, DateTime end) {
  return status.startTime != null &&
      status.startTime!.isAfter(start) &&
      status.endTime != null &&
      status.endTime!.isBefore(end);
}

/// Whether or not this goal status is completely contained within the current week.
isWithinCalendarWeek(
  DateTime now,
  StatusLogEntry status,
) {
  final beginningOfDay = now.copyWith(hour: 0, minute: 0, second: 0);
  final beginningOfWeek =
      beginningOfDay.subtract(Duration(days: now.weekday - 1));
  final endOfWeek = beginningOfWeek.add(const Duration(days: 7));

  return _statusIsBetweenDates(status, beginningOfWeek, endOfWeek);
}

/// Whether or not this goal status is completely contained within the current month.
isWithinCalendarMonth(DateTime now, StatusLogEntry status) {
  return status.startTime != null &&
      status.startTime!.year == now.year &&
      status.startTime!.month == now.month &&
      status.endTime != null &&
      status.endTime!.year == now.year &&
      status.endTime!.month == now.month;
}

isWithinQuarter(DateTime now, StatusLogEntry status) {
  return status.startTime != null &&
      status.startTime!.year == now.year &&
      (status.startTime!.month / 3).ceil() == (now.month / 3).ceil() &&
      status.endTime != null &&
      status.endTime!.year == now.year &&
      (status.endTime!.month / 3).ceil() == (now.month / 3).ceil();
}

isWithinCalendarYear(DateTime now, StatusLogEntry status) {
  return status.startTime != null &&
      status.startTime!.year == now.year &&
      status.endTime != null &&
      status.endTime!.year == now.year;
}
