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
        AddParentLogEntry,
        RemoveParentLogEntry,
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
  BehaviorSubject<Map<String, Goal>> stateSubject =
      BehaviorSubject.seeded(initialGoalState());
  late HLC hlc;
  late String clientId;
  late Box appBox;
  final PersistenceService? persistenceService;
  Future<void> syncFuture = Future.value();

  SyncClient({this.persistenceService});

  // in memory mapping from "action" ids, to the set of hlc timestamps that that action contained
  final modificationMap = <String, Set<String>>{};

  List<String> undoStack = [];
  List<String> redoStack = [];

  init() async {
    appBox = await Hive.openBox('glass_goals.sync');
    clientId = appBox.get('clientId', defaultValue: const Uuid().v4());
    hlc = HLC.now(clientId);
    _computeState();
    sync();
    Timer.periodic(const Duration(minutes: 1), (_) async {
      sync();
    });
  }

  void modifyGoal(GoalDelta delta) {
    modifyGoals([delta]);
  }

  void _computeStateOptimistic(Iterable<DeltaOp> ops) {
    Map<String, Goal> goals = {...stateSubject.value};
    applyDeltaOps(goals, ops.whereType<DeltaOp>());
    stateSubject.add(goals);
  }

  void modifyGoals(List<GoalDelta> deltas) {
    List<String> unsyncedOps =
        (appBox.get('unsyncedOps', defaultValue: []) as List<dynamic>)
            .cast<String>();

    final actionHlcs = <String>{};
    final deltaOps = <DeltaOp>[];
    for (final delta in deltas) {
      hlc = hlc.increment();
      final op = DeltaOp(hlcTimestamp: hlc.pack(), delta: delta);
      deltaOps.add(op);
      actionHlcs.add(op.hlcTimestamp);
      unsyncedOps.add(Op.toJson(op));
    }
    final actionId = const Uuid().v4();
    this.modificationMap[actionId] = actionHlcs;
    _computeStateOptimistic(deltaOps);

    appBox.put('unsyncedOps', unsyncedOps);
    sync();
    undoStack.add(actionId);
    redoStack.clear();
  }

  void undo() {
    if (undoStack.isEmpty) {
      return;
    }
    final actionToUndo = undoStack.removeLast();
    _undoAction(actionToUndo);
    redoStack.add(actionToUndo);
  }

  void redo() {
    if (redoStack.isEmpty) {
      return;
    }
    final actionToRedo = redoStack.removeLast();
    _redoAction(actionToRedo);
    undoStack.add(actionToRedo);
  }

  void _undoAction(String actionId) {
    final actionHlcs = modificationMap[actionId];
    if (actionHlcs == null) {
      throw Exception('Action not found: $actionId');
    }
    List<String> unsyncedOps =
        (appBox.get('unsyncedOps', defaultValue: []) as List<dynamic>)
            .cast<String>();
    for (final actionHlc in actionHlcs) {
      hlc = hlc.increment();
      final op = DisableOp(hlcTimestamp: hlc.pack(), hlcToDisable: actionHlc);
      unsyncedOps.add(Op.toJson(op));
    }
    appBox.put('unsyncedOps', unsyncedOps);
    _computeState();
    sync();
  }

  void _redoAction(String actionId) {
    final actionHlcs = modificationMap[actionId];
    if (actionHlcs == null) {
      throw Exception('Action not found: $actionId');
    }
    List<String> unsyncedOps =
        (appBox.get('unsyncedOps', defaultValue: []) as List<dynamic>)
            .cast<String>();
    for (final actionHlc in actionHlcs) {
      hlc = hlc.increment();
      final op = EnableOp(hlcTimestamp: hlc.pack(), hlcToEnable: actionHlc);
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
      for (final superGoalId in parent.superGoalIds) {
        if (superGoalId == goalId) {
          return true;
        }
        if (!seenIds.contains(superGoalId)) {
          newFrontierIds.add(superGoalId);
          seenIds.add(superGoalId);
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

      for (final superGoalId in goal.superGoalIds) {
        goalMap[superGoalId]!.removeSubGoal(goal.id);
      }

      goal.superGoalIds.clear();
      if (newSuperGoal != null) {
        goal.addSuperGoal(newSuperGoal.id);
        newSuperGoal.addSubGoal(goal.id);
      }
    } else if (entry is AddParentLogEntry) {
      final newSuperGoal =
          entry.parentId == null ? null : goalMap[entry.parentId];

      if (newSuperGoal == null) {
        return;
      }

      if (_checkCycles(
          goalMap, goal.id, {newSuperGoal.id}, {newSuperGoal.id})) {
        // silently ignore deltas that would create cycles ¯\_(ツ)_/¯
        return;
      }

      goal.addSuperGoal(newSuperGoal.id);
      newSuperGoal.addSubGoal(goal.id);
    } else if (entry is RemoveParentLogEntry) {
      final newSuperGoal =
          entry.parentId == null ? null : goalMap[entry.parentId];

      if (newSuperGoal == null) {
        return;
      }

      goal.removeSuperGoal(newSuperGoal.id);
      newSuperGoal.removeSubGoal(goal.id);
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
    Map<String, String> hlcMapping = {};
    for (Op op
        in ops.sorted((a, b) => a.hlcTimestamp.compareTo(b.hlcTimestamp))) {
      final newHlc = hlc.pack();
      hlcMapping[op.hlcTimestamp] = newHlc;
      final newJsonOp = Op.toJsonMap(op)..['hlcTimestamp'] = newHlc;

      if (newJsonOp.containsKey('hlcToDisable')) {
        newJsonOp['hlcToDisable'] = hlcMapping[newJsonOp['hlcToDisable']];
      }

      if (newJsonOp.containsKey('hlcToEnable')) {
        newJsonOp['hlcToEnable'] = hlcMapping[newJsonOp['hlcToEnable']];
      }

      result.add(Op.fromJsonMap(Op.toJsonMap(op)..['hlcTimestamp'] = newHlc));
      this.hlc = this.hlc.increment();
    }
    for (final hlcSet in modificationMap.values) {
      for (final hlc in [...hlcSet]) {
        if (hlcMapping.containsKey(hlc)) {
          hlcSet.remove(hlc);
          hlcSet.add(hlcMapping[hlc]!);
        }
      }
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
    if (result.ops.isNotEmpty) {
      _computeState();
    }
  }
}
