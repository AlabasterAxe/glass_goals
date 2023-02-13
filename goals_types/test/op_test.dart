import 'dart:convert' show jsonEncode;

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
          statusLogEntry: StatusLogEntry(status: GoalStatus.active)),
    );

    final json = Op.toJson(op);

    expect(
        jsonEncode(json),
        equals(
            '{"hlcTimestamp":"0","delta":{"id":"1","text":"foo","parentId":"0","statusLogEntry":{"status":"active","startTime":null,"endTime":null}},"version":2}'));

    final op2 = Op.fromJson(json);

    expect(op2, equals(op));
  });
}
