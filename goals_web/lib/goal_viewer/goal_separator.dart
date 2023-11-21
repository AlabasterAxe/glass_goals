import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';
import 'package:uuid/uuid.dart';

import '../app_context.dart';
import '../styles.dart';

class GoalSeparator extends StatefulWidget {
  final Map<String, Goal> goalMap;
  final String? previousGoalId;
  final String? nextGoalId;
  const GoalSeparator(
      {super.key, this.previousGoalId, this.nextGoalId, required this.goalMap});

  @override
  State<GoalSeparator> createState() => _GoalSeparatorState();
}

class _GoalSeparatorState extends State<GoalSeparator> {
  bool _hovered = false;

  _setGoalPriority(BuildContext context, Set<String> goalIds) {
    final List<GoalDelta> goalDeltas = [];

    final prevPriority = getGoalPriority(
        WorldContext.now(), widget.goalMap[widget.previousGoalId]!);
    final nextPriority =
        getGoalPriority(WorldContext.now(), widget.goalMap[widget.nextGoalId]!);
    final newPriority = (prevPriority + nextPriority) / 2;

    for (final goalId in goalIds) {
      goalDeltas.add(GoalDelta(
          id: goalId,
          logEntry: PriorityLogEntry(
              id: Uuid().v4(),
              creationTime: DateTime.now(),
              priority: newPriority)));
    }
    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget(
      onAccept: (_) {
        setState(() {
          _hovered = false;
        });
      },
      onMove: (details) {
        setState(() {
          _hovered = true;
        });
      },
      onLeave: (data) {
        setState(() {
          _hovered = false;
        });
      },
      builder: (_, __, ___) => SizedBox(
        height: uiUnit(2),
        child: Center(
          child: Container(
            color: this._hovered ? darkElementColor : Colors.transparent,
            height: 2,
          ),
        ),
      ),
    );
  }
}
