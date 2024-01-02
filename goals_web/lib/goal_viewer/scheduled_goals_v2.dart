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
  Set<TimeSlice> _expandedTimeSlices = {};

  Widget _smallSlice(WorldContext worldContext, TimeSlice slice,
      Map<String, Goal> sliceGoalMap) {
    final goalIds = sliceGoalMap.values
        .where((goal) {
          for (final superGoal in goal.superGoals) {
            if (sliceGoalMap.containsKey(superGoal.id)) {
              return false;
            }
          }
          return true;
        })
        .map((e) => e.id)
        .toList();
    return Row(
      children: [
        TextButton(
            onPressed: () {
              setState(() {
                _expandedTimeSlices.add(slice);
              });
            },
            child: Text(slice.displayName)),
        for (final goalId in goalIds)
          if (getGoalStatus(worldContext, sliceGoalMap[goalId]!).status ==
              GoalStatus.active) ...[
            Text("|"),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: uiUnit(2)),
              child: Text(sliceGoalMap[goalId]!.text,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ]
      ],
    );
  }

  List<Widget> _timeSlices(WorldContext worldContext, List<TimeSlice> slices) {
    final Map<String, Goal> goalsAccountedFor = {};
    final List<Widget> result = [];
    for (final (i, slice) in slices.indexed) {
      final sliceGoalMap = getGoalsForDateRange(
        worldContext,
        widget.goalMap,
        slice.startTime(worldContext.time),
        slice.endTime(worldContext.time),
      );

      for (final goalId in goalsAccountedFor.keys) {
        if (sliceGoalMap.containsKey(goalId)) {
          sliceGoalMap.remove(goalId);
        }
      }

      for (final goal in sliceGoalMap.values) {
        goalsAccountedFor[goal.id] = goal;
        goalsAccountedFor.addAll(getTransitiveSubGoals(sliceGoalMap, goal.id));
      }

      final goalIds = sliceGoalMap.values
          .where((goal) {
            for (final superGoal in goal.superGoals) {
              if (sliceGoalMap.containsKey(superGoal.id)) {
                return false;
              }
            }
            return true;
          })
          .map((e) => e.id)
          .toList();
      if (_expandedTimeSlices.contains(slice)) {
        result.add(AnimatedTheme(
          duration: const Duration(milliseconds: 100),
          data: Theme.of(this.context).copyWith(
              textButtonTheme: TextButtonThemeData(
                  style: ButtonStyle(
            textStyle: MaterialStateProperty.all(
                Theme.of(this.context).textTheme.headlineSmall),
          ))),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _expandedTimeSlices.remove(slice);
                    });
                  },
                  child: Text(
                    slice.displayName,
                  ),
                ),
                Builder(builder: (context) {
                  final onAddGoal = GoalActionsContext.of(context).onAddGoal;
                  final onDropGoal = GoalActionsContext.of(context).onDropGoal;
                  return GoalActionsContext.overrideWith(
                    context,
                    onAddGoal: (String? parentId, String text,
                            [TimeSlice? _]) =>
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
                      final goalsToUpdate =
                          selectedGoals.contains(droppedGoalId)
                              ? selectedGoals
                              : {droppedGoalId};
                      bool setNullParent =
                          goalsToUpdate.every(sliceGoalMap.containsKey);
                      bool addStatus = goalsToUpdate
                          .every((goalId) => !sliceGoalMap.containsKey(goalId));
                      for (final goalId in goalsToUpdate) {
                        if (addStatus) {
                          AppContext.of(this.context)
                              .syncClient
                              .modifyGoal(GoalDelta(
                                  id: goalId,
                                  logEntry: StatusLogEntry(
                                    id: const Uuid().v4(),
                                    creationTime: DateTime.now(),
                                    status: GoalStatus.active,
                                    startTime:
                                        slice.startTime(worldContext.time),
                                    endTime: slice.endTime(worldContext.time),
                                  )));
                        }

                        if (setNullParent &&
                            (prevDropPath?.length == 0 ||
                                prevDropPath?.length == 1) &&
                            (nextDropPath?.length == 0 ||
                                nextDropPath?.length == 1)) {
                          AppContext.of(this.context).syncClient.modifyGoal(
                              GoalDelta(
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
                      goalMap: sliceGoalMap,
                      rootGoalIds: goalIds,
                      hoverActionsBuilder: (goalId) => HoverActionsWidget(
                        goalId: goalId,
                        goalMap: widget.goalMap,
                      ),
                    ),
                  );
                })
              ]),
        ));
      } else {
        result.add(AnimatedTheme(
            duration: Duration(milliseconds: 200),
            data: Theme.of(this.context).copyWith(
                textButtonTheme: TextButtonThemeData(
                    style: ButtonStyle(
              textStyle: MaterialStateProperty.all(
                  Theme.of(this.context).textTheme.titleSmall),
            ))),
            child: _smallSlice(worldContext, slice, sliceGoalMap)));
      }
    }
    return result.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final worldContext = ref.watch(worldContextProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _timeSlices(worldContext, [
        TimeSlice.today,
        TimeSlice.this_week,
        TimeSlice.this_month,
        TimeSlice.this_quarter,
        TimeSlice.this_year,
        TimeSlice.long_term,
      ]),
    );
    ;
  }
}
