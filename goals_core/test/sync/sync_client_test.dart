import 'package:flutter_test/flutter_test.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_types/goals_types.dart'
    show GoalDelta, Op, SetParentLogEntry;
import 'package:goals_core/src/sync/sync_client.dart' show SyncClient;
import 'package:hive/hive.dart';
import 'package:hlc/hlc.dart';

Map<String, Goal> testGoals() {
  final subGoal = Goal(
    id: '2',
    text: 'bar',
    creationTime: DateTime(2020, 1, 1),
  );

  subGoal.log.add(
      SetParentLogEntry(id: '3', parentId: '0', creationTime: DateTime.now()));

  final testRootGoal = Goal(
      id: '0',
      text: 'root',
      subGoals: [subGoal],
      creationTime: DateTime(2020, 1, 1));

  final goals = <String, Goal>{};
  for (final goal in [testRootGoal, subGoal]) {
    goals[goal.id] = goal;
  }

  return goals;
}

void main() {
  test('add subgoal', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();
    var hlc = HLC.now("test");
    final goals = testGoals();
    client.applyDeltaOp(
        goals,
        Op(
            hlcTimestamp: hlc.pack(),
            delta: GoalDelta(
                id: '1',
                text: 'foo',
                logEntry: SetParentLogEntry(
                    id: '3', parentId: '0', creationTime: DateTime.now()))));
    expect(goals['0']!.subGoals.length, equals(2));

    expect(goals['0']!.subGoals[1].text, equals('foo'));
  });

  test('add subsubgoal', () {
    final client = SyncClient();
    final goals = testGoals();
    var hlc = HLC.now("test");
    client.applyDeltaOp(
        goals,
        Op(
            hlcTimestamp: hlc.pack(),
            delta: GoalDelta(
                id: '3',
                text: 'foo',
                logEntry: SetParentLogEntry(
                    id: '3', parentId: '0', creationTime: DateTime.now()))));
    expect(goals['0']!.subGoals.length, equals(1));

    expect(goals['0']!.subGoals[0].text, equals('bar'));

    expect(goals['0']!.subGoals[0].subGoals.length, equals(1));

    expect(goals['0']!.subGoals[0].subGoals[0].text, equals('foo'));
  });

  test('modifies existing goal', () {
    final client = SyncClient();
    final goals = testGoals();
    client.applyDeltaOp(
        goals,
        Op(
            hlcTimestamp: '0',
            delta: GoalDelta(
                id: '2',
                text: 'foo',
                logEntry: SetParentLogEntry(
                    id: '3', parentId: '0', creationTime: DateTime.now()))));
    expect(goals['0']!.subGoals.length, equals(1));

    expect(goals['0']!.subGoals[0].text, equals('foo'));
  });

  test('applies 2 ops', () async {
    final client = SyncClient();
    final goals = testGoals();
    Hive.init(".");
    await client.init();
    var hlc = HLC.now("test");
    client.applyDeltaOps(goals, [
      Op(
          hlcTimestamp: hlc.pack(),
          delta: GoalDelta(
              id: '3',
              text: 'foo',
              logEntry: SetParentLogEntry(
                  id: '3', parentId: '2', creationTime: DateTime.now()))),
      Op(
          hlcTimestamp: hlc.increment().pack(),
          delta: GoalDelta(
              id: '4',
              text: 'baz',
              logEntry: SetParentLogEntry(
                  id: '4', parentId: '3', creationTime: DateTime.now()))),
    ]);

    final parentGoal = goals['3']!;

    expect(parentGoal.subGoals.length, equals(1));

    final childGoal = parentGoal.subGoals[0];
    expect(childGoal.text, equals('baz'));
  });

  test('sorts by timestamp', () {
    final client = SyncClient();
    final goals = testGoals();
    client.applyDeltaOps(goals, [
      const Op(hlcTimestamp: '0', delta: GoalDelta(id: '0', text: 'foo')),
      const Op(hlcTimestamp: '2', delta: GoalDelta(id: '0', text: 'qux')),
      const Op(hlcTimestamp: '1', delta: GoalDelta(id: '0', text: 'baz')),
    ]);

    final goal = goals['0']!;

    expect(goal.text, equals('qux'));
  });

  test('rehomes goal', () {
    final client = SyncClient();
    final goals = testGoals();
    client.applyDeltaOp(
      goals,
      Op(
          hlcTimestamp: '0',
          delta: GoalDelta(
              id: '3',
              text: 'foo',
              logEntry: SetParentLogEntry(
                  id: '3', parentId: '2', creationTime: DateTime.now()))),
    );

    final parentGoal = goals['2']!;

    expect(parentGoal.subGoals.length, equals(1));

    final childGoal = parentGoal.subGoals[0];
    expect(childGoal.text, equals('foo'));

    client.applyDeltaOp(
      goals,
      Op(
          hlcTimestamp: '1',
          delta: GoalDelta(
              id: '3',
              text: 'foo',
              logEntry: SetParentLogEntry(
                  id: '4', parentId: '0', creationTime: DateTime.now()))),
    );

    expect(parentGoal.subGoals.length, equals(0));
    final newParentGoal = goals['0']!;

    expect(newParentGoal.subGoals, contains(childGoal));
    expect(childGoal.superGoals[0].id, equals('0'));
  });
}
