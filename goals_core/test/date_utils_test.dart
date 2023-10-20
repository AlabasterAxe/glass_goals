import 'package:goals_core/util.dart' show statusIsBetweenDates;
import 'package:goals_types/goals_types.dart' show GoalStatus, StatusLogEntry;
import 'package:test/expect.dart' show isFalse, isTrue;
import 'package:test/test.dart' show test, expect;

void main() {
  test('status is between dates', () {
    final startAndEnd = StatusLogEntry(
        creationTime: DateTime(2020, 1, 1, 12),
        status: GoalStatus.active,
        startTime: DateTime(2020, 1, 1, 12),
        endTime: DateTime(2020, 1, 1, 13));

    final noStart = StatusLogEntry(
        creationTime: DateTime(2020, 1, 1, 12),
        status: GoalStatus.active,
        endTime: DateTime(2020, 1, 1, 13));

    final noEnd = StatusLogEntry(
        creationTime: DateTime(2020, 1, 1, 12),
        status: GoalStatus.active,
        startTime: DateTime(2020, 1, 1, 12));

    final noStartNoEnd = StatusLogEntry(
        creationTime: DateTime(2020, 1, 1, 12), status: GoalStatus.active);

    expect(statusIsBetweenDates(startAndEnd, null, null), isTrue);
    expect(
        statusIsBetweenDates(startAndEnd, DateTime(2020, 1, 1, 11, 30), null),
        isTrue);
    expect(
        statusIsBetweenDates(startAndEnd, DateTime(2020, 1, 1, 12, 30), null),
        isFalse);
    expect(
        statusIsBetweenDates(startAndEnd, DateTime(2020, 1, 1, 13, 30), null),
        isFalse);
    expect(
        statusIsBetweenDates(startAndEnd, DateTime(2020, 1, 1, 12, 00), null),
        isFalse);

    expect(
        statusIsBetweenDates(startAndEnd, null, DateTime(2020, 1, 1, 13, 30)),
        isTrue);
    expect(
        statusIsBetweenDates(startAndEnd, null, DateTime(2020, 1, 1, 11, 30)),
        isFalse);
    expect(
        statusIsBetweenDates(startAndEnd, null, DateTime(2020, 1, 1, 12, 30)),
        isFalse);
    expect(
        statusIsBetweenDates(startAndEnd, null, DateTime(2020, 1, 1, 13, 00)),
        isFalse);

    expect(statusIsBetweenDates(noStart, null, null), isTrue);
    expect(statusIsBetweenDates(noEnd, null, null), isTrue);
    expect(statusIsBetweenDates(noStartNoEnd, null, null), isTrue);
  });
}
