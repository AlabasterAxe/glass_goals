import 'dart:async';
import 'dart:developer';

import 'package:hive/hive.dart' show Box, Hive;
import 'package:hlc/hlc.dart';
import 'package:rxdart/rxdart.dart' show BehaviorSubject, Subject;
import 'package:uuid/uuid.dart';

import 'package:goals_core/model.dart' show Goal;
import 'package:goals_types/goals_types.dart' show GoalDelta, Op;
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

  SyncClient({this.persistenceService});

  init() async {
    appBox = await Hive.openBox('glass_goals.sync');
    clientId = appBox.get('clientId', defaultValue: const Uuid().v4());
    hlc = HLC.now(clientId!);
    _computeState();
    sync();
    Timer.periodic(const Duration(minutes: 1), (_) async {
      _computeState();
    });
  }

  void modifyGoal(GoalDelta delta) {
    hlc = hlc.increment();
    List<String> unsyncedOps =
        (appBox.get('unsyncedOps', defaultValue: []) as List<dynamic>)
            .cast<String>();

    final op = Op(hlcTimestamp: hlc.pack(), delta: delta);
    unsyncedOps.add(Op.toJson(op));
    appBox.put('unsyncedOps', unsyncedOps);
    _computeState();
    sync();
  }

  void modifyGoals(List<GoalDelta> deltas) {
    List<String> unsyncedOps =
        (appBox.get('unsyncedOps', defaultValue: []) as List<dynamic>)
            .cast<String>();

    for (final delta in deltas) {
      hlc = hlc.increment();
      final op = Op(hlcTimestamp: hlc.pack(), delta: delta);
      unsyncedOps.add(Op.toJson(op));
    }

    appBox.put('unsyncedOps', unsyncedOps);
    _computeState();
    sync();
  }

  _checkCycles(Map<String, Goal> goalMap, String goalId, String? parentId) {
    if (parentId == null) {
      return false;
    }

    if (goalId == parentId) {
      return true;
    }

    final parent = goalMap[parentId];
    if (parent == null) {
      throw Exception('Parent goal not found: $parentId');
    }

    return _checkCycles(goalMap, goalId, parent.parentId);
  }

  applyOp(Map<String, Goal> goalMap, Op op) {
    hlc = hlc.receive(HLC.unpack(op.hlcTimestamp));
    Goal? goal = goalMap[op.delta.id];

    if (_checkCycles(goalMap, op.delta.id, op.delta.parentId)) {
      // silently ignore deltas that would create cycles.
      return;
    }

    if (goal == null) {
      goalMap[op.delta.id] = goal = Goal(
          id: op.delta.id,
          text: op.delta.text ?? 'Untitled',
          parentId: op.delta.parentId);
    }

    if (op.delta.text != null && goal.text != op.delta.text) {
      goal.text = op.delta.text!;
    }

    if (op.delta.statusLogEntry != null) {
      goal.log.add(op.delta.statusLogEntry!);
    }

    if (goal.parentId != null &&
        op.delta.parentId != null &&
        goal.parentId != op.delta.parentId) {
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

  Iterable<Op> _getOpsFromBox(String fieldName) {
    final boxContents =
        appBox.get(fieldName, defaultValue: []) as List<dynamic>;
    return boxContents.cast<String>().map(Op.fromJson).toList();
  }

  _computeState() {
    List<Op> ops = _getOpsFromBox('ops').toList();

    ops.addAll(_getOpsFromBox('unsyncedOps'));

    Map<String, Goal> goals = initialGoalState();

    applyOps(goals, ops);

    return stateSubject.add(goals);
  }

  Future<void> sync() async {
    if (persistenceService == null) {
      return;
    }
    final int? cursor = appBox.get('syncCursor');
    final List<String> ops =
        (appBox.get('ops', defaultValue: []) as List<dynamic>).cast<String>();
    final Set<String> localOps =
        Set.from(_getOpsFromBox('ops').map((op) => op.hlcTimestamp));

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
    final Iterable<Op> unsyncedOps = _getOpsFromBox('unsyncedOps');
    if (unsyncedOps.isNotEmpty) {
      try {
        await persistenceService!.save(unsyncedOps);
        ops.addAll(unsyncedOps.map(Op.toJson));
        await appBox.put('unsyncedOps', []);
      } catch (e) {
        log('Save failed', error: e);
      }
    }
    await appBox.put('ops', ops);
    await appBox.put('lastSyncDateTime', DateTime.now().toIso8601String());
    _computeState();
  }
}
