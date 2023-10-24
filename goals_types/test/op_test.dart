import 'package:test/test.dart';
import 'package:goals_types/goals_types.dart'
    show GoalDelta, GoalStatus, Op, StatusLogEntry;
import 'package:goals_types_03/goals_types.dart' as prev_goal_types;

void main() {
  test('op to json works', () {
    final op = Op(
      hlcTimestamp: '0',
      delta: GoalDelta(
          id: '1',
          text: 'foo',
          logEntry: StatusLogEntry(
              id: '2',
              creationTime: DateTime(2023),
              status: GoalStatus.active)),
    );

    final json = Op.toJson(op);

    expect(
        json,
        equals(
            '{"hlcTimestamp":"0","delta":{"id":"1","text":"foo","logEntry":{"type":"status","status":"active","creationTime":"2023-01-01T05:00:00.000Z","startTime":null,"endTime":null}},"version":4}'));

    final op2 = Op.fromJson(json);

    expect(op2, equals(op));
  });
  test('prev op to json works', () {
    final op = prev_goal_types.Op(
      hlcTimestamp: '0',
      delta: prev_goal_types.GoalDelta(id: '1', text: 'foo', parentId: '0'),
    );

    final newOp = Op(
        delta: GoalDelta.fromPrevious(op.delta), hlcTimestamp: op.hlcTimestamp);

    final json = Op.toJson(newOp);

    expect(
        json,
        equals(
            '{"hlcTimestamp":"0","delta":{"id":"1","text":"foo","logEntry":{"type":"setParent","parentId":"0","creationTime":"2023-01-01T05:00:00.000Z"}},"version":4}'));

    final op2 = Op.fromJson(json);

    expect(op2, equals(newOp));
  });
}
