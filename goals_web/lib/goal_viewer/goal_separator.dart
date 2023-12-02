import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/flattened_goal_tree.dart';
import 'package:uuid/uuid.dart';

import '../app_context.dart';
import '../styles.dart';

class GoalSeparator extends StatefulWidget {
  final Map<String, Goal> goalMap;
  final List<String> previousGoalPath;
  final List<String> nextGoalPath;
  const GoalSeparator(
      {super.key,
      this.previousGoalPath = const [],
      this.nextGoalPath = const [],
      required this.goalMap});

  @override
  State<GoalSeparator> createState() => _GoalSeparatorState();
}

// A
// - sep
// B
// - sep
// C
// - sep
//   D
//   - sep
//   E
//   - sep
//   add goal
// - sep
// F

class _GoalSeparatorState extends State<GoalSeparator> {
  bool _hovered = false;

  _setGoalPriority(BuildContext context, Set<String> goalIds) {
    final List<GoalDelta> goalDeltas = [];

    final prevGoalId = widget.previousGoalPath.lastOrNull;
    final nextGoalId = widget.nextGoalPath.lastOrNull;

    final worldContext = WorldContext.now();

    // cases
    //  - dropped between siblings => set parent to path[length - 2], priority to average of siblings
    //  - dropped between parent and child => set parent to last element of previous path, priority to midpoint between 0 and first child priority
    //  - dropped after last child and before add goal entry => set parent to path[length - 2], priority to last child priority * 2
    //  - dropped after add goal entry => set parent to next path[length - 2], priority to average between parent goal of previous path and priority of last child of next path

    String? newParentId;
    double? newPriority;
    if (widget.previousGoalPath.length == widget.nextGoalPath.length) {
      // dropped between siblings
      newParentId = widget.previousGoalPath.length >= 2
          ? widget.previousGoalPath[widget.previousGoalPath.length - 2]
          : null;

      final prevPriority = prevGoalId == null
          ? null
          : getGoalPriority(WorldContext.now(), widget.goalMap[prevGoalId]!);
      final nextPriority = nextGoalId == null ||
              nextGoalId == NEW_GOAL_PLACEHOLDER
          ? null
          : getGoalPriority(WorldContext.now(), widget.goalMap[nextGoalId]!);

      if (nextPriority != null && prevPriority != null) {
        newPriority = (prevPriority + nextPriority) / 2;
      } else if (prevPriority != null) {
        newPriority = null;
      }
    } else if (widget.previousGoalPath.length ==
        widget.nextGoalPath.length - 1) {
      // dropped between parent and child
      newParentId = widget.previousGoalPath.lastOrNull;
      newPriority = nextGoalId == NEW_GOAL_PLACEHOLDER
          ? null
          : getGoalPriority(worldContext, widget.goalMap[nextGoalId]!) / 2;
    } else if (widget.previousGoalPath.length > widget.nextGoalPath.length) {
      // dropped after last child and before add goal entry

      newParentId = widget.nextGoalPath.length >= 2
          ? widget.nextGoalPath[widget.nextGoalPath.length - 2]
          : null;

      final addGoalParentId = widget.previousGoalPath.length >= 2
          ? widget.previousGoalPath[widget.previousGoalPath.length - 2]
          : null;
      final prevGoal = widget.goalMap[addGoalParentId];
      final prevPriority =
          prevGoal == null ? null : getGoalPriority(worldContext, prevGoal);
      final nextPriority =
          nextGoalId == null || nextGoalId == NEW_GOAL_PLACEHOLDER
              ? null
              : getGoalPriority(worldContext, widget.goalMap[nextGoalId]!);

      if (nextPriority != null && prevPriority != null) {
        newPriority = (prevPriority + nextPriority) / 2;
      } else if (prevPriority != null) {
        newPriority = null;
      }
    }

    for (final goalId in goalIds) {
      goalDeltas.add(GoalDelta(
          id: goalId,
          logEntry: SetParentLogEntry(
              id: Uuid().v4(),
              parentId: newParentId,
              creationTime: DateTime.now())));
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
      onAccept: (String goalId) {
        _setGoalPriority(context, {goalId});
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
