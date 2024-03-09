import 'package:goals_core/sync.dart' show StatusLogEntry;
import 'package:intl/intl.dart' show DateFormat;

formatDate(DateTime date) {
  return DateFormat('yyyy.MM.dd.').format(date) +
      DateFormat('EE').format(date).substring(0, 2).toUpperCase();
}

formatTime(DateTime date) {
  return DateFormat(DateFormat.HOUR_MINUTE).format(date);
}

bool statusIsBetweenDatesInclusive(
    StatusLogEntry status, DateTime? start, DateTime? end) {
  if (end != null && start != null && end.isBefore(start)) {
    throw ArgumentError('end must be after start');
  }
  return (start == null ||
          (status.startTime != null &&
              status.startTime!
                  .isAfter(start.subtract(const Duration(seconds: 1))))) &&
      (end == null ||
          (status.endTime != null &&
              status.endTime!.isBefore(end.add(const Duration(seconds: 1)))));
}

isWithinDay(
  DateTime now,
  StatusLogEntry status,
) {
  return statusIsBetweenDatesInclusive(
    status,
    now.startOfDay,
    now.endOfDay,
  );
}

extension DateTimeExtension on DateTime {
  DateTime get startOfDay => this
      .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime get endOfDay => this.copyWith(
      hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
  DateTime get startOfWeek =>
      this.startOfDay.subtract(Duration(days: this.weekday - 1));
  DateTime get endOfWeek => this
      .startOfWeek
      .add(const Duration(days: 7))
      .subtract(const Duration(microseconds: 1));

  DateTime get startOfMonth => this.copyWith(
      day: 1, hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime get endOfMonth => DateTime(this.year, this.month + 1)
      .subtract(const Duration(microseconds: 1));
  DateTime get startOfQuarter =>
      DateTime(this.year, (this.month / 3).ceil() * 3 - 2);
  DateTime get endOfQuarter {
    final currentQuarter = (this.month / 3).ceil();
    return currentQuarter == 4
        ? DateTime(this.year + 1).subtract(const Duration(microseconds: 1))
        : DateTime(this.year, currentQuarter * 3 + 1)
            .subtract(const Duration(microseconds: 1));
  }

  DateTime get startOfYear => DateTime(this.year);
  DateTime get endOfYear => DateTime(this.year, 12, 31, 23, 59, 59, 999, 999);
}

/// Whether or not this goal status is completely contained within the current week.
isWithinCalendarWeek(
  DateTime now,
  StatusLogEntry status,
) {
  return statusIsBetweenDatesInclusive(status, now.startOfWeek, now.endOfWeek);
}

/// Whether or not this goal status is completely contained within the current month.
isWithinCalendarMonth(DateTime now, StatusLogEntry status) {
  return statusIsBetweenDatesInclusive(
      status, now.startOfMonth, now.endOfMonth);
}

isWithinQuarter(DateTime now, StatusLogEntry status) {
  return statusIsBetweenDatesInclusive(
      status, now.startOfQuarter, now.endOfQuarter);
}

isWithinCalendarYear(DateTime now, StatusLogEntry status) {
  return statusIsBetweenDatesInclusive(status, now.startOfYear, now.endOfYear);
}
