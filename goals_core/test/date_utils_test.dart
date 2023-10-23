import 'package:goals_core/util.dart' show statusIsBetweenDatesInclusive;
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

    expect(statusIsBetweenDatesInclusive(startAndEnd, null, null), isTrue);
    expect(
        statusIsBetweenDatesInclusive(
            startAndEnd, DateTime(2020, 1, 1, 11, 30), null),
        isTrue);
    expect(
        statusIsBetweenDatesInclusive(
            startAndEnd, DateTime(2020, 1, 1, 12, 30), null),
        isFalse);
    expect(
        statusIsBetweenDatesInclusive(
            startAndEnd, DateTime(2020, 1, 1, 13, 30), null),
        isFalse);
    expect(
        statusIsBetweenDatesInclusive(
            startAndEnd, DateTime(2020, 1, 1, 12, 00), null),
        isFalse);

    expect(
        statusIsBetweenDatesInclusive(
            startAndEnd, null, DateTime(2020, 1, 1, 13, 30)),
        isTrue);
    expect(
        statusIsBetweenDatesInclusive(
            startAndEnd, null, DateTime(2020, 1, 1, 11, 30)),
        isFalse);
    expect(
        statusIsBetweenDatesInclusive(
            startAndEnd, null, DateTime(2020, 1, 1, 12, 30)),
        isFalse);
    expect(
        statusIsBetweenDatesInclusive(
            startAndEnd, null, DateTime(2020, 1, 1, 13, 00)),
        isFalse);

    expect(statusIsBetweenDatesInclusive(noStart, null, null), isTrue);
    expect(statusIsBetweenDatesInclusive(noEnd, null, null), isTrue);
    expect(statusIsBetweenDatesInclusive(noStartNoEnd, null, null), isTrue);
  });
}
