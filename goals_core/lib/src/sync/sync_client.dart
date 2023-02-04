import 'dart:async';
import 'dart:developer';

import 'package:hive/hive.dart' show Box, Hive;
import 'package:hlc/hlc.dart';
import 'package:rxdart/rxdart.dart' show BehaviorSubject, Subject;
import 'package:uuid/uuid.dart';

import 'package:goals_core/model.dart' show Goal;
import 'ops.dart' show GoalDelta, Op;
import 'persistence_service.dart' show PersistenceService;

final rootGoal = Goal(id: 'root', text: 'Live a fulfilling life');
final archiveGoal = Goal(id: 'archive', text: 'Archive');

Map<String, Goal> initialGoalState() =>
    {'root': rootGoal, 'archive': archiveGoal};

class SyncClient {
  Subject<Map<String, Goal>> stateSubject =
      BehaviorSubject.seeded(initialGoalState());
  late HLC hlc;
  String? clientId;
  late Box appBox;
  final PersistenceService? persistenceService;
  late Timer _syncTimer;

  SyncClient({this.persistenceService});

  init() async {
    appBox = await Hive.openBox('glass_goals.sync');
    clientId = appBox.get('clientId', defaultValue: const Uuid().v4());
    hlc = HLC.now(clientId!);
    _computeState();
    sync();
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      _computeState();
    });
  }

  modifyGoal(GoalDelta delta) {
    hlc = hlc.increment();
    List<dynamic> unsyncedOps = appBox.get('unsyncedOps', defaultValue: []);

    final op = Op(hlcTimestamp: hlc.pack(), delta: delta);
    unsyncedOps.add(Op.toJson(op));
    appBox.put('unsyncedOps', unsyncedOps);
    _computeState();
    sync();
  }

  modifyGoals(List<GoalDelta> deltas) {
    List<dynamic> unsyncedOps = appBox.get('unsyncedOps', defaultValue: []);

    for (final delta in deltas) {
      hlc = hlc.increment();
      final op = Op(hlcTimestamp: hlc.pack(), delta: delta);
      unsyncedOps.add(Op.toJson(op));
    }

    appBox.put('unsyncedOps', unsyncedOps);
    _computeState();
    sync();
  }

  applyOp(Map<String, Goal> goalMap, Op op) {
    Goal? goal = goalMap[op.delta.id];
    if (goal == null) {
      goalMap[op.delta.id] = goal = Goal(
          id: op.delta.id,
          text: op.delta.text ?? 'Untitled',
          parentId: op.delta.parentId);
    }

    if (op.delta.text != null && goal.text != op.delta.text) {
      goal.text = op.delta.text!;
    }

    if (op.delta.activeUntil != null &&
        goal.activeUntil != op.delta.activeUntil) {
      goal.activeUntil = op.delta.activeUntil!;
    }

    if (op.delta.parentId != null && goal.parentId != op.delta.parentId) {
      goalMap[goal.parentId!]?.removeSubGoal(goal.id);
      goal.parentId = op.delta.parentId;
    }

    if (goal.parentId != null) {
      goalMap[goal.parentId!]?.addOrReplaceSubGoal(goal);
    }
  }

  applyOps(Map<String, Goal> goalMap, List<Op> ops) {
    ops.sort((a, b) => a.hlcTimestamp.compareTo(b.hlcTimestamp));

    for (Op op in ops) {
      applyOp(goalMap, op);
    }
  }

  _computeState() {
    List<Op> ops = (appBox.get('ops', defaultValue: []) as List<dynamic>)
        .map(Op.fromJson)
        .toList();

    ops.addAll((appBox.get('unsyncedOps', defaultValue: []) as List<dynamic>)
        .map(Op.fromJson)
        .toList());

    Map<String, Goal> goals = initialGoalState();

    applyOps(goals, ops);

    return stateSubject.add(goals);
  }

  Future<void> sync() async {
    if (persistenceService == null) {
      return;
    }
    final int? cursor = appBox.get('syncCursor');
    final List<dynamic> ops = appBox.get('ops', defaultValue: []);
    final Set<String> localOps = Set.from(
        (appBox.get('ops', defaultValue: []) as List<dynamic>)
            .map(Op.fromJson)
            .map((op) => op.hlcTimestamp));

    try {
      final result = await persistenceService!.load(cursor: cursor);
      appBox.put('syncCursor', result.cursor);
      for (Op op in result.ops) {
        if (!localOps.contains(op.hlcTimestamp)) {
          ops.add(Op.toJson(op));
        }
      }
    } catch (e) {
      log('Fetch failed', error: e);
    }
    final List<dynamic> unsyncedOps =
        appBox.get('unsyncedOps', defaultValue: []);
    if (unsyncedOps.isNotEmpty) {
      await persistenceService!.save(unsyncedOps.map(Op.fromJson).toList());
      ops.addAll(unsyncedOps);
      await appBox.put('unsyncedOps', []);
    }
    await appBox.put('ops', ops);
    await appBox.put('lastSyncDateTime', DateTime.now().toIso8601String());
    _computeState();
  }
}
