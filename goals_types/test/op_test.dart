import 'package:test/test.dart';
import 'package:goals_types/goals_types.dart'
    show DeltaOp, GoalDelta, GoalStatus, Op, StatusLogEntry;
import 'package:goals_types_04/goals_types.dart' as prev_goal_types;
import 'package:uuid/uuid.dart';

void main() {
  test('op to json works', () {
    final op = DeltaOp(
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
            '{"hlcTimestamp":"0","delta":{"id":"1","text":"foo","logEntry":{"type":"status","id":"2","status":"active","creationTime":"2023-01-01T05:00:00.000Z","startTime":null,"endTime":null}},"version":5,"type":"delta"}'));

    final op2 = Op.fromJson(json);

    expect(op2, equals(op));
  });
  test('prev op to json works', () {
    final entryId = const Uuid().v4();
    final op = prev_goal_types.Op(
      hlcTimestamp: '0',
      delta: prev_goal_types.GoalDelta(
          id: '1',
          text: 'foo',
          logEntry: prev_goal_types.SetParentLogEntry(
            id: entryId,
            creationTime: DateTime(2023),
            parentId: '0',
          )),
    );

    final newOp = DeltaOp(
        delta: GoalDelta.fromPrevious(op.delta), hlcTimestamp: op.hlcTimestamp);

    final json = Op.toJson(newOp);

    expect(
        json,
        equals(
            '{"hlcTimestamp":"0","delta":{"id":"1","text":"foo","logEntry":{"type":"setParent","id":"$entryId","parentId":"0","creationTime":"2023-01-01T05:00:00.000Z"}},"version":5,"type":"delta"}'));

    final op2 = Op.fromJson(json);

    expect(op2, equals(newOp));
  });
}
