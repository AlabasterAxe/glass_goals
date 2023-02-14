import 'package:flutter_test/flutter_test.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_types/goals_types.dart' show Op, GoalDelta;
import 'package:goals_core/src/sync/sync_client.dart' show SyncClient;

Map<String, Goal> testGoals() {
  final subGoal = Goal(
    id: '2',
    text: 'bar',
    parentId: '0',
  );

  final testRootGoal =
      Goal(id: '0', text: 'root', parentId: null, subGoals: [subGoal]);

  final goals = <String, Goal>{};
  for (final goal in [testRootGoal, subGoal]) {
    goals[goal.id] = goal;
  }

  return goals;
}

void main() {
  test('add subgoal', () {
    final client = SyncClient();
    final goals = testGoals();
    client.applyOp(
        goals,
        const Op(
            hlcTimestamp: '0',
            delta: GoalDelta(id: '1', text: 'foo', parentId: '0')));
    expect(goals['0']!.subGoals.length, equals(2));

    expect(goals['0']!.subGoals[1].text, equals('foo'));
  });

  test('add subsubgoal', () {
    final client = SyncClient();
    final goals = testGoals();
    client.applyOp(
        goals,
        const Op(
            hlcTimestamp: '0',
            delta: GoalDelta(id: '3', text: 'foo', parentId: '2')));
    expect(goals['0']!.subGoals.length, equals(1));

    expect(goals['0']!.subGoals[0].text, equals('bar'));

    expect(goals['0']!.subGoals[0].subGoals.length, equals(1));

    expect(goals['0']!.subGoals[0].subGoals[0].text, equals('foo'));
  });

  test('modifies existing goal', () {
    final client = SyncClient();
    final goals = testGoals();
    client.applyOp(
        goals,
        const Op(
            hlcTimestamp: '0',
            delta: GoalDelta(id: '2', text: 'foo', parentId: '0')));
    expect(goals['0']!.subGoals.length, equals(1));

    expect(goals['0']!.subGoals[0].text, equals('foo'));
  });

  test('applies 2 ops', () {
    final client = SyncClient();
    final goals = testGoals();
    client.applyOps(goals, [
      const Op(
          hlcTimestamp: '0',
          delta: GoalDelta(id: '3', text: 'foo', parentId: '2')),
      const Op(
          hlcTimestamp: '1',
          delta: GoalDelta(id: '4', text: 'baz', parentId: '3')),
    ]);

    final parentGoal = goals['3']!;

    expect(parentGoal.subGoals.length, equals(1));

    final childGoal = parentGoal.subGoals[0];
    expect(childGoal.text, equals('baz'));
  });

  test('sorts by timestamp', () {
    final client = SyncClient();
    final goals = testGoals();
    client.applyOps(goals, [
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
    client.applyOp(
      goals,
      const Op(
          hlcTimestamp: '0',
          delta: GoalDelta(id: '3', text: 'foo', parentId: '2')),
    );

    final parentGoal = goals['2']!;

    expect(parentGoal.subGoals.length, equals(1));

    final childGoal = parentGoal.subGoals[0];
    expect(childGoal.text, equals('foo'));

    client.applyOp(
      goals,
      const Op(
          hlcTimestamp: '1',
          delta: GoalDelta(id: '3', text: 'foo', parentId: '0')),
    );

    expect(parentGoal.subGoals.length, equals(0));
    final newParentGoal = goals['0']!;

    expect(newParentGoal.subGoals, contains(childGoal));
    expect(childGoal.parentId, equals('0'));
  });
}
