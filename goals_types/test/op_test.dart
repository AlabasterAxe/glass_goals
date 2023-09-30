import 'package:test/test.dart';
import 'package:goals_types/goals_types.dart'
    show GoalDelta, GoalStatus, Op, StatusLogEntry;

void main() {
  test('op to json works', () {
    final op = Op(
      hlcTimestamp: '0',
      delta: GoalDelta(
          id: '1',
          text: 'foo',
          parentId: '0',
          logEntry: StatusLogEntry(
              creationTime: DateTime(2023), status: GoalStatus.active)),
    );

    final json = Op.toJson(op);

    expect(
        json,
        equals(
            '{"hlcTimestamp":"0","delta":{"id":"1","text":"foo","parentId":"0","statusLogEntry":{"status":"active","creationTime":"2023-01-01T05:00:00.000Z","startTime":null,"endTime":null}},"version":2}'));

    final op2 = Op.fromJson(json);

    expect(op2, equals(op));
  });
}
