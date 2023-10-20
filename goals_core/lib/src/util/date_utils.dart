import 'package:goals_core/sync.dart' show StatusLogEntry;
import 'package:intl/intl.dart' show DateFormat;

formatDate(DateTime date) {
  return DateFormat('yyyy.MM.dd.').format(date) +
      DateFormat('EE').format(date).substring(0, 2).toUpperCase();
}

bool statusIsBetweenDates(
    StatusLogEntry status, DateTime? start, DateTime? end) {
  if (end != null && start != null && end.isBefore(start)) {
    throw ArgumentError('end must be after start');
  }
  return (start == null ||
          (status.startTime != null && status.startTime!.isAfter(start))) &&
      (end == null ||
          (status.endTime != null && status.endTime!.isBefore(end)));
}

isWithinDay(
  DateTime now,
  StatusLogEntry status,
) {
  return statusIsBetweenDates(
    status,
    now.startOfDay,
    now.endOfDay.add(const Duration(seconds: 1)),
  );
}

extension DateTimeExtension on DateTime {
  DateTime get startOfDay => this.copyWith(hour: 0, minute: 0, second: 0);
  DateTime get endOfDay => this.copyWith(hour: 23, minute: 59, second: 59);
  DateTime get startOfWeek =>
      this.startOfDay.subtract(Duration(days: this.weekday - 1));
  DateTime get endOfWeek => this
      .startOfWeek
      .add(const Duration(days: 7))
      .subtract(const Duration(seconds: 1));

  DateTime get startOfMonth => this.copyWith(day: 1);
  DateTime get endOfMonth => DateTime(this.year, this.month + 1, 1)
      .subtract(const Duration(seconds: 1));
  DateTime get startOfQuarter =>
      DateTime(this.year, (this.month / 3).ceil() * 3 - 2, 1);
  DateTime get endOfQuarter {
    final currentQuarter = (this.month / 3).ceil();
    return currentQuarter == 4
        ? DateTime(this.year + 1, 1, 1).subtract(const Duration(seconds: 1))
        : DateTime(this.year, currentQuarter * 3 + 1, 1)
            .subtract(const Duration(seconds: 1));
  }

  DateTime get startOfYear => DateTime(this.year, 1, 1);
  DateTime get endOfYear => DateTime(this.year, 12, 31, 23, 59, 59);
}

/// Whether or not this goal status is completely contained within the current week.
isWithinCalendarWeek(
  DateTime now,
  StatusLogEntry status,
) {
  return statusIsBetweenDates(
      status, now.startOfWeek, now.endOfWeek.add(const Duration(seconds: 1)));
}

/// Whether or not this goal status is completely contained within the current month.
isWithinCalendarMonth(DateTime now, StatusLogEntry status) {
  return statusIsBetweenDates(
      status, now.startOfMonth, now.endOfMonth.add(const Duration(seconds: 1)));
}

isWithinQuarter(DateTime now, StatusLogEntry status) {
  return statusIsBetweenDates(status, now.startOfQuarter,
      now.endOfQuarter.add(const Duration(seconds: 1)));
}

isWithinCalendarYear(DateTime now, StatusLogEntry status) {
  return statusIsBetweenDates(
      status, now.startOfYear, now.endOfYear.add(const Duration(seconds: 1)));
}
