import 'package:flutter/material.dart';
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, SetParentLogEntry, StatusLogEntry;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import 'package:uuid/uuid.dart';

import '../app_context.dart';
import '../common/time_slice.dart';
import '../styles.dart';
import 'flattened_goal_tree.dart';
import 'goal_actions_context.dart';
import 'hover_actions.dart';
import 'providers.dart';

class ScheduledGoalsV2 extends ConsumerStatefulWidget {
  final Map<String, Goal> goalMap;
  const ScheduledGoalsV2({
    super.key,
    required this.goalMap,
  });

  @override
  ConsumerState<ScheduledGoalsV2> createState() => _ScheduledGoalsV2State();
}

class _ScheduledGoalsV2State extends ConsumerState<ScheduledGoalsV2> {
  List<Widget> _timeSlices(WorldContext worldContext, List<TimeSlice> slices) {
    final Map<String, Goal> goalsAccountedFor = {};
    final List<Widget> result = [];
    for (final slice in slices) {
      final goalMap = getGoalsForDateRange(
        worldContext,
        widget.goalMap,
        slice.startTime(worldContext.time),
        slice.endTime(worldContext.time),
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

      final goalIds = goalMap.values
          .where((goal) {
            for (final superGoal in goal.superGoals) {
              if (goalMap.containsKey(superGoal.id)) {
                return false;
              }
            }
            return true;
          })
          .map((e) => e.id)
          .toList();
      result.add(Padding(
        padding: EdgeInsets.all(uiUnit(2)),
        child: Text(
          slice.displayName,
          style: Theme.of(this.context).textTheme.headlineSmall,
        ),
      ));
      result.add(Builder(builder: (context) {
        final onAddGoal = GoalActionsContext.of(context).onAddGoal;
        final onDropGoal = GoalActionsContext.of(context).onDropGoal;
        return GoalActionsContext.overrideWith(
          context,
          onAddGoal: (String? parentId, String text, [TimeSlice? _]) =>
              onAddGoal(parentId, text, slice),
          onDropGoal: (
            droppedGoalId, {
            List<String>? dropPath,
            List<String>? prevDropPath,
            List<String>? nextDropPath,
          }) {
            onDropGoal(
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
                      startTime: slice.startTime(worldContext.time),
                      endTime: slice.endTime(worldContext.time),
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
          child: FlattenedGoalTree(
            section: slice.name,
            goalMap: goalMap,
            rootGoalIds: goalIds,
            hoverActionsBuilder: (goalId) => HoverActionsWidget(
              goalId: goalId,
              goalMap: widget.goalMap,
            ),
          ),
        );
      }));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
