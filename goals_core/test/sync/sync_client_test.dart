import 'package:flutter_test/flutter_test.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_types/goals_types.dart'
    show DeltaOp, GoalDelta, SetParentLogEntry;
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

  subGoal.addSuperGoal(testRootGoal.id);

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
        DeltaOp(
            hlcTimestamp: hlc.pack(),
            delta: GoalDelta(
                id: '1',
                text: 'foo',
                logEntry: SetParentLogEntry(
                    id: '3', parentId: '0', creationTime: DateTime.now()))));
    expect(goals['0']!.subGoalIds.length, equals(2));

    expect(goals[goals['0']!.subGoalIds[1]]!.text, equals('foo'));
  });

  test('add subsubgoal', () async {
    final client = SyncClient();
    Hive.init(".");
    await client.init();

    final goals = testGoals();
    var hlc = HLC.now("test");
    client.applyDeltaOp(
        goals,
        DeltaOp(
            hlcTimestamp: hlc.pack(),
            delta: GoalDelta(
                id: '3',
                text: 'foo',
                logEntry: SetParentLogEntry(
                    id: '3', parentId: '2', creationTime: DateTime.now()))));
    expect(goals['0']!.subGoalIds.length, equals(1));

    expect(goals[goals['0']!.subGoalIds[0]]!.text, equals('bar'));

    expect(goals[goals['0']!.subGoalIds[0]]!.subGoalIds.length, equals(1));

    expect(goals[goals[goals['0']!.subGoalIds[0]]!.subGoalIds[0]]!.text,
        equals('foo'));
  });

  test('modifies existing goal', () async {
    final client = SyncClient();
    await client.init();
    final goals = testGoals();
    final hlc = HLC.now("test");
    client.applyDeltaOp(
        goals,
        DeltaOp(
            hlcTimestamp: hlc.pack(),
            delta: GoalDelta(
                id: '2',
                text: 'foo',
                logEntry: SetParentLogEntry(
                    id: '3', parentId: '0', creationTime: DateTime.now()))));
    expect(goals['0']!.subGoalIds.length, equals(1));

    expect(goals[goals['0']!.subGoalIds[0]]!.text, equals('foo'));
  });

  test('applies 2 ops', () async {
    final client = SyncClient();
    await client.init();

    final goals = testGoals();
    Hive.init(".");
    await client.init();
    var hlc = HLC.now("test");
    client.applyDeltaOps(goals, [
      DeltaOp(
          hlcTimestamp: hlc.pack(),
          delta: GoalDelta(
              id: '3',
              text: 'foo',
              logEntry: SetParentLogEntry(
                  id: '3', parentId: '2', creationTime: DateTime.now()))),
      DeltaOp(
          hlcTimestamp: hlc.increment().pack(),
          delta: GoalDelta(
              id: '4',
              text: 'baz',
              logEntry: SetParentLogEntry(
                  id: '4', parentId: '3', creationTime: DateTime.now()))),
    ]);

    final parentGoal = goals['3']!;

    expect(parentGoal.subGoalIds.length, equals(1));

    final childGoalId = parentGoal.subGoalIds[0];
    expect(goals[childGoalId]!.text, equals('baz'));
  });

  test('sorts by timestamp', () async {
    Hive.init(".");

    final client = SyncClient();
    await client.init();

    final goals = testGoals();

    var hlc = HLC.now("test");
    final hlc1 = hlc.pack();

    hlc = hlc.increment();
    final hlc2 = hlc.pack();

    hlc = hlc.increment();
    final hlc3 = hlc.pack();

    client.applyDeltaOps(goals, [
      DeltaOp(hlcTimestamp: hlc1, delta: GoalDelta(id: '0', text: 'foo')),
      DeltaOp(hlcTimestamp: hlc3, delta: GoalDelta(id: '0', text: 'qux')),
      DeltaOp(hlcTimestamp: hlc2, delta: GoalDelta(id: '0', text: 'baz')),
    ]);

    final goal = goals['0']!;

    expect(goal.text, equals('qux'));
  });

  test('rehomes goal', () async {
    Hive.init(".");
    final client = SyncClient();
    await client.init();
    final goals = testGoals();
    client.applyDeltaOp(
      goals,
      DeltaOp(
          hlcTimestamp: '0:0:0',
          delta: GoalDelta(
              id: '3',
              text: 'foo',
              logEntry: SetParentLogEntry(
                  id: '3', parentId: '2', creationTime: DateTime.now()))),
    );

    final parentGoal = goals['2']!;

    expect(parentGoal.subGoalIds.length, equals(1));

    final childGoalId = parentGoal.subGoalIds[0];
    expect(goals[childGoalId]!.text, equals('foo'));

    client.applyDeltaOp(
      goals,
      DeltaOp(
          hlcTimestamp: '1:0:0',
          delta: GoalDelta(
              id: '3',
              text: 'foo',
              logEntry: SetParentLogEntry(
                  id: '4', parentId: '0', creationTime: DateTime.now()))),
    );

    expect(parentGoal.subGoalIds.length, equals(0));
    final newParentGoal = goals['0']!;

    expect(newParentGoal.subGoalIds, contains(childGoalId));
    expect(goals[goals[childGoalId]!.superGoalIds[0]]!.id, equals('0'));
  });

  test('undo', () async {
    Hive.init(".");
    final client = SyncClient();
    await client.init();
    client.modifyGoal(GoalDelta(
      id: '0',
      text: 'root',
    ));
    client.modifyGoal(GoalDelta(
      id: '2',
      text: 'bar',
    ));
    client.modifyGoal(
      GoalDelta(
          id: '2',
          text: 'foo',
          logEntry: SetParentLogEntry(
              id: '2', parentId: '0', creationTime: DateTime.now())),
    );
    client.modifyGoal(
      GoalDelta(
          id: '3',
          text: 'foo',
          logEntry: SetParentLogEntry(
              id: '3', parentId: '2', creationTime: DateTime.now())),
    );

    final initialState = await client.stateSubject.first;

    var parentGoal = initialState['2']!;

    expect(parentGoal.subGoalIds.length, equals(1));

    var childGoalId = parentGoal.subGoalIds[0];
    expect(initialState[childGoalId]!.text, equals('foo'));

    client.modifyGoal(
      GoalDelta(
          id: '3',
          text: 'foo',
          logEntry: SetParentLogEntry(
              id: '4', parentId: '0', creationTime: DateTime.now())),
    );

    final newState = await client.stateSubject.first;

    parentGoal = newState['2']!;

    expect(parentGoal.subGoalIds.length, equals(0));
    final newParentGoal = newState['0']!;

    final newChildGoal = newState['3']!;
    expect(newParentGoal.subGoalIds, contains(childGoalId));
    expect(newChildGoal.superGoalIds[0], equals('0'));

    client.undo();

    final previousState = await client.stateSubject.first;
    parentGoal = previousState['2']!;

    expect(parentGoal.subGoalIds.length, equals(1));

    childGoalId = parentGoal.subGoalIds[0];
    expect(previousState[childGoalId]!.text, equals('foo'));

    client.redo();

    final redoneState = await client.stateSubject.first;

    parentGoal = redoneState['2']!;

    expect(parentGoal.subGoalIds.length, equals(0));
    final redoneParentGoal = redoneState['0']!;

    final redoneChildGoal = redoneState['3']!;
    expect(redoneParentGoal.subGoalIds, contains(childGoalId));
    expect(redoneChildGoal.superGoalIds[0], equals('0'));
  });
}
