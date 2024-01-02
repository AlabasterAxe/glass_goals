import 'package:flutter/material.dart';

class ScheduledGoalsV2 extends StatefulWidget {
  const ScheduledGoalsV2({super.key});

  @override
  State<ScheduledGoalsV2> createState() => _ScheduledGoalsV2State();
}

class _ScheduledGoalsV2State extends State<ScheduledGoalsV2> {
  List<Widget> _timeSlices(WorldContext context, List<TimeSlice> slices) {
    final Map<String, Goal> goalsAccountedFor = {};
    final List<Widget> result = [];
    for (final slice in slices) {
      final goalMap = getGoalsForDateRange(
        context,
        widget.goalMap,
        slice.startTime(context.time),
        slice.endTime(context.time),
      );

      if (goalMap.isEmpty && slice.zoomDown != null) {
        continue;
      }

      for (final goalId in goalsAccountedFor.keys) {
        if (goalMap.containsKey(goalId)) {
          goalMap.remove(goalId);
        }
      }

      for (final goal in goalMap.values) {
        goalsAccountedFor[goal.id] = goal;
        goalsAccountedFor.addAll(getTransitiveSubGoals(goalMap, goal.id));
      }

      final goalIds = _mode == GoalViewMode.tree
          ? goalMap.values
              .where((goal) {
                for (final superGoal in goal.superGoals) {
                  if (goalMap.containsKey(superGoal.id)) {
                    return false;
                  }
                }
                return true;
              })
              .map((e) => e.id)
              .toList()
          : (goalMap.values.toList(growable: false)
                ..sort((a, b) =>
                    a.text.toLowerCase().compareTo(b.text.toLowerCase())))
              .map((g) => g.id)
              .toList();
      result.add(Padding(
        padding: EdgeInsets.all(uiUnit(2)),
        child: Text(
          slice.displayName,
          style: Theme.of(this.context).textTheme.headlineSmall,
        ),
      ));
      result.add(FlattenedGoalTree(
        section: slice.name,
        goalMap: goalMap,
        rootGoalIds: goalIds,
        onSelected: onSelected,
        onExpanded: onExpanded,
        onFocused: onFocused,
        hoverActionsBuilder: (goalId) => HoverActionsWidget(
          goalId: goalId,
          onUnarchive: onUnarchive,
          onArchive: onArchive,
          onDone: onDone,
          onSnooze: onSnooze,
          onActive: onActive,
          goalMap: widget.goalMap,
        ),
        depthLimit: _mode == GoalViewMode.list ? 1 : null,
        onAddGoal: (String? parentId, String text) =>
            this._onAddGoal(parentId, text, slice),
        onDropGoal: (
          droppedGoalId, {
          List<String>? dropPath,
          List<String>? prevDropPath,
          List<String>? nextDropPath,
        }) {
          this._handleDrop(
            droppedGoalId,
            dropPath: dropPath,
            prevDropPath: prevDropPath,
            nextDropPath: nextDropPath,
          );
          final selectedGoals = ref.read(selectedGoalsProvider);
          final goalsToUpdate = selectedGoals.contains(droppedGoalId)
              ? selectedGoals
              : {droppedGoalId};
          bool setNullParent = goalsToUpdate.every(goalMap.containsKey);
          bool addStatus =
              goalsToUpdate.every((goalId) => !goalMap.containsKey(goalId));
          for (final goalId in goalsToUpdate) {
            if (addStatus) {
              AppContext.of(this.context).syncClient.modifyGoal(GoalDelta(
                  id: goalId,
                  logEntry: StatusLogEntry(
                    id: const Uuid().v4(),
                    creationTime: DateTime.now(),
                    status: GoalStatus.active,
                    startTime: slice.startTime(context.time),
                    endTime: slice.endTime(context.time),
                  )));
            }

            if (setNullParent &&
                (prevDropPath?.length == 0 || prevDropPath?.length == 1) &&
                (nextDropPath?.length == 0 || nextDropPath?.length == 1)) {
              AppContext.of(this.context).syncClient.modifyGoal(GoalDelta(
                  id: goalId,
                  logEntry: SetParentLogEntry(
                      id: const Uuid().v4(),
                      parentId: null,
                      creationTime: DateTime.now())));
            }
          }
        },
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
