import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';
import 'package:test/test.dart';

Map<String, Goal> testGoals() {
  final testRootGoal = Goal(id: '0', text: 'root', parentId: null);

  final goals = <String, Goal>{};
  goals[testRootGoal.id] = testRootGoal;

  return goals;
}

void main() {
  test('getActiveGoalExpiringSoonest', () {
    final client = SyncClient();
    final Map<String, Goal> goals = testGoals();
    client.applyOps(goals, [
      Op(
          hlcTimestamp: '0',
          delta: GoalDelta(
              id: '0',
              statusLogEntry: StatusLogEntry(
                  status: GoalStatus.active,
                  creationTime: DateTime(2020, 1, 1, 12),
                  startTime: DateTime(2020, 1, 1, 12),
                  endTime: DateTime(2020, 1, 1, 12)))),
    ]);

    expect(
        getActiveGoalExpiringSoonest(
            WorldContext(time: DateTime(2020, 1, 1, 13)), goals),
        isNull);
  });

  test('getActiveGoalExpiringSoonest, unset active', () {
    final client = SyncClient();
    final Map<String, Goal> goals = testGoals();
    client.applyOps(goals, [
      Op(
          hlcTimestamp: '0',
          delta: GoalDelta(
              id: '0',
              statusLogEntry: StatusLogEntry(
                  status: GoalStatus.active,
                  creationTime: DateTime(2020, 1, 1, 12),
                  startTime: DateTime(2020, 1, 1, 12),
                  endTime: DateTime(2020, 1, 2, 12)))),
      Op(
          hlcTimestamp: '0',
          delta: GoalDelta(
              id: '0',
              statusLogEntry: StatusLogEntry(
                  status: GoalStatus.active,
                  creationTime: DateTime(2020, 1, 1, 12),
                  startTime: DateTime(2020, 1, 1, 12),
                  endTime: DateTime(2020, 1, 1, 13)))),
    ]);

    expect(
        getActiveGoalExpiringSoonest(
            WorldContext(time: DateTime(2020, 1, 1, 13)), goals),
        isNull);
  });
}
