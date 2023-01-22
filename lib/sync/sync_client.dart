import 'package:hive_flutter/hive_flutter.dart' show Box, Hive, HiveX;
import 'package:hlc/hlc.dart';
import 'package:rxdart/rxdart.dart' show BehaviorSubject, Subject;
import 'package:uuid/uuid.dart';

import '../model.dart' show Goal;
import 'ops.dart' show GoalDelta, Op;
import 'persistence_service.dart' show PersistenceService;

final rootGoal = Goal(id: '0', text: 'Live a fulfilling life');

class SyncClient {
  Subject<List<Goal>> stateSubject = BehaviorSubject.seeded([rootGoal]);
  HLC? hlc;
  String? clientId;
  Box? appBox;
  final PersistenceService? persistenceService;

  SyncClient({this.persistenceService});

  init() async {
    await Hive.initFlutter();
    appBox = await Hive.openBox('glass_goals');
    clientId = appBox!.get('clientId', defaultValue: const Uuid().v4());
    hlc = HLC.now(clientId!);
    _computeState();
  }

  modifyGoal(GoalDelta delta) {
    hlc = hlc!.increment();
    List<dynamic> unsyncedOps = appBox!.get('unsyncedOps', defaultValue: []);

    final op = Op(hlcTimestamp: hlc!.pack(), delta: delta);
    unsyncedOps.add(Op.toJson(op));
    appBox!.put('unsyncedOps', unsyncedOps);
    _computeState();
    sync();
  }

  void _computeState() {
    Map<String, Goal> goals = {
      '0': rootGoal,
    };
    List<Op> ops = (appBox!.get('ops', defaultValue: []) as List<dynamic>)
        .map(Op.fromJson)
        .toList();

    ops.addAll((appBox!.get('unsyncedOps', defaultValue: []) as List<dynamic>)
        .map(Op.fromJson)
        .toList());

    ops.sort((a, b) => a.hlcTimestamp.compareTo(b.hlcTimestamp));
    for (final op in ops) {
      Goal? goal = goals[op.delta.id] ??
          Goal(
              id: op.delta.id,
              text: op.delta.text ?? 'Untitled',
              parentId: op.delta.parentId);

      if (op.delta.text != null && goal.text != op.delta.text) {
        goal.text = op.delta.text!;
      }

      if (op.delta.parentId != null && goal.parentId != op.delta.parentId) {
        goals[goal.parentId!]?.removeSubGoal(goal.id);
        goal.parentId = op.delta.parentId;
      }

      if (goal.parentId != null) {
        goals[goal.parentId!]?.addOrReplaceSubGoal(goal);
      }
    }

    return stateSubject.add([goals['0']!]);
  }

  Future<void> sync() async {
    if (persistenceService == null) {
      return;
    }
    await persistenceService!
        .save(appBox!.get('unsyncedOps', defaultValue: []).map(Op.fromJson));
    await appBox!.put('unsyncedOps', []);
  }
}
