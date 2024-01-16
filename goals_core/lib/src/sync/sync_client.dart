import 'dart:async';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:hive/hive.dart' show Box, Hive;
import 'package:hlc/hlc.dart';
import 'package:rxdart/rxdart.dart' show BehaviorSubject, Subject;
import 'package:uuid/uuid.dart';

import 'package:goals_core/model.dart' show Goal;
import 'package:goals_types/goals_types.dart'
    show
        DeltaOp,
        DisableOp,
        EnableOp,
        GoalDelta,
        GoalLogEntry,
        Op,
        SetParentLogEntry;
import 'persistence_service.dart' show PersistenceService;

Map<String, Goal> initialGoalState() => {};

class SyncClient {
  Subject<Map<String, Goal>> stateSubject =
      BehaviorSubject.seeded(initialGoalState());
  late HLC hlc;
  late String clientId;
  late Box appBox;
  final PersistenceService? persistenceService;
  Future<void> syncFuture = Future.value();

  SyncClient({this.persistenceService});

  init() async {
    appBox = await Hive.openBox('glass_goals.sync');
    clientId = appBox.get('clientId', defaultValue: const Uuid().v4());
    hlc = HLC.now(clientId);
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

    final op = DeltaOp(hlcTimestamp: hlc.pack(), delta: delta);
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
      final op = DeltaOp(hlcTimestamp: hlc.pack(), delta: delta);
      unsyncedOps.add(Op.toJson(op));
    }

    appBox.put('unsyncedOps', unsyncedOps);
    _computeState();
    sync();
  }

  _checkCycles(Map<String, Goal> goalMap, String goalId,
      Set<String> frontierIds, Set<String> seenIds) {
    if (frontierIds.isEmpty) {
      return false;
    }

    if (frontierIds.contains(goalId)) {
      return true;
    }

    Set<String> newFrontierIds = {};
    for (final parentId in frontierIds) {
      final parent = goalMap[parentId];
      if (parent == null) {
        throw Exception('Parent goal not found: $parentId');
      }
      for (final superGoal in parent.superGoals) {
        if (superGoal.id == goalId) {
          return true;
        }
        if (!seenIds.contains(superGoal.id)) {
          newFrontierIds.add(superGoal.id);
          seenIds.add(superGoal.id);
        }
      }
    }

    return _checkCycles(goalMap, goalId, newFrontierIds, seenIds);
  }

  void _evaluateSuperGoals(
      Map<String, Goal> goalMap, Goal goal, GoalLogEntry? entry) {
    if (entry is SetParentLogEntry) {
      final newSuperGoal =
          entry.parentId == null ? null : goalMap[entry.parentId];

      if (newSuperGoal != null &&
          _checkCycles(
              goalMap, goal.id, {newSuperGoal.id}, {newSuperGoal.id})) {
        // silently ignore deltas that would create cycles ¯\_(ツ)_/¯
        return;
      }

      for (final superGoal in goal.superGoals) {
        superGoal.removeSubGoal(goal.id);
      }

      goal.superGoals.clear();
      if (newSuperGoal != null) {
        goal.superGoals.add(newSuperGoal);
        newSuperGoal.addOrReplaceSubGoal(goal);
      }
    }
  }

  applyDeltaOp(Map<String, Goal> goalMap, DeltaOp op,
      [Set<String> disabledOps = const {}]) {
    if (disabledOps.contains(op.hlcTimestamp)) {
      return;
    }
    final opHlc = HLC.unpack(op.hlcTimestamp);
    hlc = hlc.receive(opHlc);
    Goal? goal = goalMap[op.delta.id];

    if (goal == null) {
      goalMap[op.delta.id] = goal = Goal(
          id: op.delta.id,
          text: op.delta.text ?? 'Untitled',
          creationTime: DateTime.fromMillisecondsSinceEpoch(opHlc.timestamp));
    }

    if (op.delta.text != null && goal.text != op.delta.text) {
      goal.text = op.delta.text!;
    }

    if (op.delta.logEntry != null) {
      goal.log.add(op.delta.logEntry!);
      _evaluateSuperGoals(goalMap, goal, op.delta.logEntry);
    }
  }

  applyDeltaOps(Map<String, Goal> goalMap, Iterable<DeltaOp> ops,
      [Set<String> disabledOps = const {}]) {
    for (final op
        in ops.sorted((a, b) => a.hlcTimestamp.compareTo(b.hlcTimestamp))) {
      applyDeltaOp(goalMap, op, disabledOps);
    }
  }

  Iterable<Op> _getOpsFromBox(String fieldName) {
    final hlcs = <String>{};
    final boxContents =
        appBox.get(fieldName, defaultValue: []) as List<dynamic>;
    final result = <Op>[];
    for (final String opString in boxContents.cast<String>()) {
      final op = Op.fromJson(opString);
      if (!hlcs.contains(op.hlcTimestamp)) {
        hlcs.add(op.hlcTimestamp);
        result.add(op);
      }
    }
    return result;
  }

  Set<String> _computeDisabledOps(List<Op> ops) {
    final disabledOps = <String>{};

    for (final op in ops) {
      if (op is DisableOp) {
        disabledOps.add(op.hlcToDisable);
      } else if (op is EnableOp) {
        disabledOps.remove(op.hlcToEnable);
      }
    }

    return disabledOps;
  }

  _computeState() {
    List<Op> ops = _getOpsFromBox('ops').toList();

    ops.addAll(_getOpsFromBox('unsyncedOps'));

    ops.sort((a, b) => a.hlcTimestamp.compareTo(b.hlcTimestamp));

    Map<String, Goal> goals = initialGoalState();

    applyDeltaOps(
        goals, ops.whereType<DeltaOp>(), this._computeDisabledOps(ops));

    return stateSubject.add(goals);
  }

  Iterable<Op> _reHlcOps(HLC? remote, Iterable<Op> ops) {
    if (remote != null) {
      this.hlc.receive(remote);
    }

    List<Op> result = [];
    for (Op op
        in ops.sorted((a, b) => a.hlcTimestamp.compareTo(b.hlcTimestamp))) {
      result
          .add(Op.fromJsonMap(Op.toJsonMap(op)..['hlcTimestamp'] = hlc.pack()));
      this.hlc = this.hlc.increment();
    }
    return result;
  }

  Future<void> sync() async {
    final currentSyncFuture = this.syncFuture;
    final syncCompleter = Completer<void>();
    this.syncFuture = syncCompleter.future;
    await currentSyncFuture;
    if (persistenceService == null) {
      return;
    }
    final int? cursor = appBox.get('syncCursor');
    final List<String> ops =
        (appBox.get('ops', defaultValue: []) as List<dynamic>).cast<String>();
    String? maxHlcTimestamp;
    final Set<String> localOps = Set.from(_getOpsFromBox('ops').map((op) {
      if (maxHlcTimestamp == null ||
          op.hlcTimestamp.compareTo(maxHlcTimestamp!) > 0) {
        maxHlcTimestamp = op.hlcTimestamp;
      }
      return op.hlcTimestamp;
    }));

    final result = await persistenceService!.load(cursor: cursor);
    appBox.put('syncCursor', result.cursor);
    for (Op op in result.ops) {
      if (!localOps.contains(op.hlcTimestamp)) {
        ops.add(Op.toJson(op));
      }
    }

    Iterable<Op> unsyncedOps = _getOpsFromBox('unsyncedOps');
    if (unsyncedOps.isNotEmpty) {
      unsyncedOps = _reHlcOps(
          maxHlcTimestamp != null ? HLC.unpack(maxHlcTimestamp!) : null,
          unsyncedOps.toList().reversed);
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
    syncCompleter.complete();
    _computeState();
  }
}
