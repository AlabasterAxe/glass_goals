import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';
import 'package:hive/hive.dart';
import 'package:hlc/hlc.dart';
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
              logEntry: StatusLogEntry(
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

  test('getActiveGoalExpiringSoonest, unset active', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();

    final Map<String, Goal> goals = testGoals();
    var hlc = HLC.now("test");
    client.applyOps(goals, [
      Op(
          hlcTimestamp: hlc.pack(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  status: GoalStatus.active,
                  creationTime: DateTime(2020, 1, 1, 12),
                  startTime: DateTime(2020, 1, 1, 12),
                  endTime: DateTime(2020, 1, 2, 12)))),
      Op(
          hlcTimestamp: hlc.increment().pack(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  creationTime: DateTime(2020, 1, 1, 13),
                  startTime: DateTime(2020, 1, 1, 13)))),
    ]);

    expect(
        getActiveGoalExpiringSoonest(
            WorldContext(time: DateTime(2020, 1, 1, 14)), goals),
        isNull);
  });

  test('getGoalStatus, happy path', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();

    final Map<String, Goal> goals = testGoals();
    var hlc = HLC.now("test");
    client.applyOps(goals, [
      Op(
          hlcTimestamp: hlc.pack(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  status: GoalStatus.active,
                  creationTime: DateTime(2020, 1, 1, 12),
                  startTime: DateTime(2020, 1, 1, 12),
                  endTime: DateTime(2020, 1, 2, 12)))),
    ]);

    expect(
        getGoalStatus(WorldContext(time: DateTime(2020, 1, 1, 14)), goals['0']!)
            .status,
        equals(GoalStatus.active));
  });
  test('getGoalStatus, patches', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();

    final Map<String, Goal> goals = testGoals();
    var hlc = HLC.now("test");

    tick() {
      hlc = hlc.increment();
      return hlc.pack();
    }

    client.applyOps(goals, [
      Op(
          hlcTimestamp: tick(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  status: GoalStatus.active,
                  creationTime: DateTime(2020, 1, 1, 12),
                  startTime: DateTime(2020, 1, 1, 12),
                  endTime: DateTime(2020, 1, 2, 12)))),
      Op(
          hlcTimestamp: tick(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  creationTime: DateTime(2020, 1, 1, 13),
                  startTime: DateTime(2020, 1, 1, 13),
                  endTime: DateTime(2020, 1, 1, 14)))),
      Op(
          hlcTimestamp: tick(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  creationTime: DateTime(2020, 1, 1, 15),
                  startTime: DateTime(2020, 1, 1, 15),
                  endTime: DateTime(2020, 1, 1, 16)))),
      Op(
          hlcTimestamp: tick(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  creationTime: DateTime(2020, 1, 1, 17),
                  status: GoalStatus.pending,
                  startTime: DateTime(2020, 1, 1, 17),
                  endTime: DateTime(2020, 1, 1, 18)))),
    ]);

    expect(
        getGoalStatus(
                WorldContext(time: DateTime(2020, 1, 1, 14, 30)), goals['0']!)
            .status,
        equals(GoalStatus.active));
    expect(
        getGoalStatus(
                WorldContext(time: DateTime(2020, 1, 1, 13, 30)), goals['0']!)
            .status,
        isNull);
    expect(
        getGoalStatus(
                WorldContext(time: DateTime(2020, 1, 1, 17, 30)), goals['0']!)
            .status,
        GoalStatus.pending);
    expect(
        getGoalStatus(
                WorldContext(time: DateTime(2020, 1, 2, 8, 30)), goals['0']!)
            .status,
        GoalStatus.active);
  });

  test('getGoalsRequiringAttention, clustering', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();

    final Map<String, Goal> goals = testGoals();
    var hlc = HLC.now("test");

    tick() {
      hlc = hlc.increment();
      return hlc.pack();
    }

    client.applyOps(goals, [
      Op(
        hlcTimestamp: tick(),
        delta: GoalDelta(id: '0'),
      ),
      Op(
        hlcTimestamp: tick(),
        delta: GoalDelta(id: '1', parentId: '0'),
      ),
      Op(
        hlcTimestamp: tick(),
        delta: GoalDelta(id: '2', parentId: '0'),
      ),
    ]);

    final requiringAttention = getGoalsRequiringAttention(
        WorldContext(time: DateTime(2020, 1, 1, 14, 30)), goals);

    expect(requiringAttention, contains('0'));
    expect(requiringAttention, contains('1'));
    expect(requiringAttention, contains('2'));
  });

  test('getGoalsRequiringAttention, subclustering', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();

    final Map<String, Goal> goals = testGoals();
    var hlc = HLC.now("test");

    tick() {
      hlc = hlc.increment();
      return hlc.pack();
    }

    client.applyOps(goals, [
      Op(
        hlcTimestamp: tick(),
        delta: GoalDelta(id: 'root'),
      ),
      Op(
        hlcTimestamp: tick(),
        delta: GoalDelta(id: 'child', parentId: 'root'),
      ),
      Op(
        hlcTimestamp: tick(),
        delta: GoalDelta(id: '2', parentId: 'root'),
      ),
    ]);

    final requiringAttention = getGoalsRequiringAttention(
        WorldContext(time: DateTime(2020, 1, 1, 14, 30)), goals);

    expect(requiringAttention, contains('0'));
    expect(requiringAttention, contains('1'));
    expect(requiringAttention, contains('2'));
  });
}
