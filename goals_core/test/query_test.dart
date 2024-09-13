import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';
import 'package:goals_core/util.dart';
import 'package:hive/hive.dart';
import 'package:hlc/hlc.dart';
import 'package:test/test.dart';

Map<String, Goal> testGoals() {
  final testRootGoal =
      Goal(id: '0', text: 'root', creationTime: DateTime(2020, 1, 1));

  final goals = <String, Goal>{};
  goals[testRootGoal.id] = testRootGoal;

  return goals;
}

void main() {
  test('getActiveGoalExpiringSoonest', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();

    final Map<String, Goal> goals = testGoals();
    var hlc = HLC.now("test");
    client.applyDeltaOps(goals, [
      DeltaOp(
          hlcTimestamp: hlc.pack(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  id: '1',
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
    client.applyDeltaOps(goals, [
      DeltaOp(
          hlcTimestamp: hlc.pack(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  id: '1',
                  status: GoalStatus.active,
                  creationTime: DateTime(2020, 1, 1, 12),
                  startTime: DateTime(2020, 1, 1, 12),
                  endTime: DateTime(2020, 1, 2, 12)))),
      DeltaOp(
          hlcTimestamp: hlc.increment().pack(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  id: '2',
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
    client.applyDeltaOps(goals, [
      DeltaOp(
          hlcTimestamp: hlc.pack(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  id: '1',
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

    client.applyDeltaOps(goals, [
      DeltaOp(
          hlcTimestamp: tick(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  id: '1',
                  status: GoalStatus.active,
                  creationTime: DateTime(2020, 1, 1, 12),
                  startTime: DateTime(2020, 1, 1, 12),
                  endTime: DateTime(2020, 1, 2, 12)))),
      DeltaOp(
          hlcTimestamp: tick(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  id: '2',
                  creationTime: DateTime(2020, 1, 1, 13),
                  startTime: DateTime(2020, 1, 1, 13),
                  endTime: DateTime(2020, 1, 1, 14)))),
      DeltaOp(
          hlcTimestamp: tick(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  id: '3',
                  creationTime: DateTime(2020, 1, 1, 15),
                  startTime: DateTime(2020, 1, 1, 15),
                  endTime: DateTime(2020, 1, 1, 16)))),
      DeltaOp(
          hlcTimestamp: tick(),
          delta: GoalDelta(
              id: '0',
              logEntry: StatusLogEntry(
                  id: '4',
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

    client.applyDeltaOps(goals, [
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(id: '0'),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: '1',
            logEntry: SetParentLogEntry(
                id: '3', creationTime: DateTime.now(), parentId: '0')),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: '2',
            logEntry: SetParentLogEntry(
                id: '4', creationTime: DateTime.now(), parentId: '0')),
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

    final Map<String, Goal> goals = {};
    var hlc = HLC.now("test");

    tick() {
      hlc = hlc.increment();
      return hlc.pack();
    }

    client.applyDeltaOps(goals, [
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'root',
            logEntry: StatusLogEntry(
                id: '1', creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'child-1',
            logEntry: SetParentLogEntry(
                id: '2',
                parentId: 'root',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'child-1',
            logEntry: StatusLogEntry(
                id: '3',
                status: GoalStatus.active,
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'child-2',
            logEntry: SetParentLogEntry(
                id: '2',
                parentId: 'root',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1-1',
            logEntry: SetParentLogEntry(
                id: '4',
                parentId: 'child',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1-1',
            logEntry: StatusLogEntry(
                id: '5',
                status: GoalStatus.active,
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1-2',
            logEntry: SetParentLogEntry(
                id: '6',
                parentId: 'child',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1-2',
            logEntry: StatusLogEntry(
                id: '7',
                status: GoalStatus.active,
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-2-1',
            logEntry: SetParentLogEntry(
                id: '6',
                parentId: 'child-2',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
    ]);

    final requiringAttention = getGoalsRequiringAttention(
        WorldContext(time: DateTime(2020, 1, 1, 14, 30)), goals);

    expect(requiringAttention, contains('child-2'));
    expect(requiringAttention, contains('sub-child-2-1'));
  });

  test('getTransitiveSubgoals', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();

    final Map<String, Goal> goals = {};
    var hlc = HLC.now("test");

    tick() {
      hlc = hlc.increment();
      return hlc.pack();
    }

    client.applyDeltaOps(goals, [
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'root',
            logEntry: StatusLogEntry(
                id: '1', creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'child',
            logEntry: SetParentLogEntry(
                id: '2',
                parentId: 'root',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'child',
            logEntry: StatusLogEntry(
                id: '3',
                status: GoalStatus.active,
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1',
            logEntry: SetParentLogEntry(
                id: '4',
                parentId: 'child',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1',
            logEntry: StatusLogEntry(
                id: '5',
                status: GoalStatus.active,
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-2',
            logEntry: SetParentLogEntry(
                id: '6',
                parentId: 'child',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-2',
            logEntry: StatusLogEntry(
                id: '7',
                status: GoalStatus.active,
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
    ]);

    final transitiveSubGoals = getTransitiveSubGoals(goals, 'root');

    expect(transitiveSubGoals, contains('child'));
    expect(transitiveSubGoals, contains('sub-child-1'));
    expect(transitiveSubGoals, contains('sub-child-2'));
  });

  test('getTransitiveSubgoals, with predicate', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();

    final Map<String, Goal> goals = {};
    var hlc = HLC.now("test");

    tick() {
      hlc = hlc.increment();
      return hlc.pack();
    }

    client.applyDeltaOps(goals, [
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'root',
            logEntry: StatusLogEntry(
                id: '1', creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'child',
            logEntry: SetParentLogEntry(
                id: '2',
                parentId: 'root',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'child',
            logEntry: StatusLogEntry(
                id: '3',
                status: GoalStatus.active,
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1',
            logEntry: SetParentLogEntry(
                id: '4',
                parentId: 'child',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1',
            logEntry: StatusLogEntry(
                id: '5',
                status: GoalStatus.active,
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-2',
            logEntry: SetParentLogEntry(
                id: '6',
                parentId: 'child',
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-2',
            logEntry: StatusLogEntry(
                id: '7',
                status: GoalStatus.active,
                creationTime: DateTime(2020, 1, 1, 12))),
      ),
    ]);

    final transitiveSubGoals = getTransitiveSubGoals(goals, 'root',
        predicate: (goal) => !goal.id.startsWith('sub'));

    expect(transitiveSubGoals, contains('child'));
    expect(transitiveSubGoals, isNot(contains('sub-child-1')));
    expect(transitiveSubGoals, isNot(contains('sub-child-2')));
  });

  test('getGoalsForDateRange', () async {
    final client = SyncClient();

    Hive.init(".");
    await client.init();

    final Map<String, Goal> goals = {};
    var hlc = HLC.now("test");

    tick() {
      hlc = hlc.increment();
      return hlc.pack();
    }

    final now = DateTime(2020, 1, 1, 12);

    client.applyDeltaOps(goals, [
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'root', logEntry: StatusLogEntry(id: '1', creationTime: now)),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'child',
            logEntry: SetParentLogEntry(
                id: '2', parentId: 'root', creationTime: now)),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'child',
            logEntry: StatusLogEntry(
                id: '3', status: GoalStatus.active, creationTime: now)),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1',
            logEntry: SetParentLogEntry(
                id: '4', parentId: 'child', creationTime: now)),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-1',
            logEntry: StatusLogEntry(
                id: '5', status: GoalStatus.active, creationTime: now)),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-2',
            logEntry: SetParentLogEntry(
                id: '6', parentId: 'child', creationTime: now)),
      ),
      DeltaOp(
        hlcTimestamp: tick(),
        delta: GoalDelta(
            id: 'sub-child-2',
            logEntry: StatusLogEntry(
              id: '7',
              status: GoalStatus.active,
              creationTime: now,
              startTime: now.startOfYear,
              endTime: now.endOfYear,
            )),
      ),
    ]);

    final yearlyGoals = getGoalsForDateRange(WorldContext(time: now), goals,
        now.startOfYear, now.endOfYear, now.startOfQuarter, now.endOfQuarter);

    expect(yearlyGoals, contains('sub-child-2'));
  });

  test('traverseDown', () async {
    Goal parent =
        Goal(id: 'parent', text: 'parent', creationTime: DateTime(2020, 1, 1));
    Goal child =
        Goal(id: 'child', text: 'child', creationTime: DateTime(2020, 1, 1));

    parent.addSubGoal(child.id);
    child.superGoalIds.add(parent.id);

    Goal grandChild = Goal(
        id: 'grandChild',
        text: 'grandChild',
        creationTime: DateTime(2020, 1, 1));

    child.addSubGoal(grandChild.id);
    grandChild.superGoalIds.add(child.id);

    final goalMap = {
      parent.id: parent,
      child.id: child,
      grandChild.id: grandChild
    };

    final goalIds = [];
    final paths = [];
    traverseDown(goalMap, parent.id, onVisit: (goalId, path) {
      goalIds.add(goalId);
      paths.add(path);
    });

    expect(goalIds, equals(['parent', 'child', 'grandChild']));
    expect(
        paths,
        equals([
          [],
          ['parent'],
          ['parent', 'child']
        ]));
  });

  test('traverseDown, stopTraversal', () async {
    Goal parent =
        Goal(id: 'parent', text: 'parent', creationTime: DateTime(2020, 1, 1));
    Goal child =
        Goal(id: 'child', text: 'child', creationTime: DateTime(2020, 1, 1));

    parent.addSubGoal(child.id);
    child.superGoalIds.add(parent.id);

    Goal grandChild = Goal(
        id: 'grandChild',
        text: 'grandChild',
        creationTime: DateTime(2020, 1, 1));

    child.addSubGoal(grandChild.id);
    grandChild.superGoalIds.add(child.id);

    final goalMap = {
      parent.id: parent,
      child.id: child,
      grandChild.id: grandChild
    };

    final goalIds = [];
    final paths = [];
    traverseDown(goalMap, parent.id, onVisit: (goalId, path) {
      goalIds.add(goalId);
      paths.add(path);
      return TraversalDecision.stopTraversal;
    });

    expect(goalIds, equals(['parent']));
    expect(
        paths,
        equals([
          [],
        ]));
  });

  test('traverseDown, dontRecurse', () async {
    Goal parent =
        Goal(id: 'parent', text: 'parent', creationTime: DateTime(2020, 1, 1));
    Goal child =
        Goal(id: 'child', text: 'child', creationTime: DateTime(2020, 1, 1));
    Goal sibling = Goal(
        id: 'sibling', text: 'sibling', creationTime: DateTime(2020, 1, 1));

    parent.addSubGoal(child.id);
    child.superGoalIds.add(parent.id);

    parent.addSubGoal(sibling.id);
    sibling.superGoalIds.add(parent.id);

    Goal grandChild = Goal(
        id: 'grandChild',
        text: 'grandChild',
        creationTime: DateTime(2020, 1, 1));

    child.addSubGoal(grandChild.id);
    grandChild.superGoalIds.add(child.id);

    final goalMap = {
      parent.id: parent,
      child.id: child,
      grandChild.id: grandChild,
      sibling.id: sibling,
    };

    final goalIds = [];
    final paths = [];
    traverseDown(goalMap, parent.id, onVisit: (goalId, path) {
      goalIds.add(goalId);
      paths.add(path);
      if (goalId == 'child') {
        return TraversalDecision.dontRecurse;
      }
      return TraversalDecision.continueTraversal;
    });

    expect(goalIds, equals(['parent', 'child', 'sibling']));
    expect(
        paths,
        equals([
          [],
          ['parent'],
          ['parent'],
        ]));
  });

  test('traverseDown, missing from map', () async {
    Goal parent =
        Goal(id: 'parent', text: 'parent', creationTime: DateTime(2020, 1, 1));
    Goal child =
        Goal(id: 'child', text: 'child', creationTime: DateTime(2020, 1, 1));
    Goal sibling = Goal(
        id: 'sibling', text: 'sibling', creationTime: DateTime(2020, 1, 1));

    parent.addSubGoal(child.id);
    child.superGoalIds.add(parent.id);

    parent.addSubGoal(sibling.id);
    sibling.superGoalIds.add(parent.id);

    Goal grandChild = Goal(
        id: 'grandChild',
        text: 'grandChild',
        creationTime: DateTime(2020, 1, 1));

    child.addSubGoal(grandChild.id);
    grandChild.superGoalIds.add(child.id);

    final goalMap = {
      parent.id: parent,
      grandChild.id: grandChild,
      sibling.id: sibling,
    };

    final goalIds = [];
    final paths = [];
    traverseDown(goalMap, parent.id, onVisit: (goalId, path) {
      goalIds.add(goalId);
      paths.add(path);
    });

    expect(goalIds, equals(['parent', 'sibling']));
    expect(
        paths,
        equals([
          [],
          ['parent'],
        ]));
  });
}
