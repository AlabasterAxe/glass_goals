import 'package:flutter/material.dart';
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, SetParentLogEntry, StatusLogEntry;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import 'package:uuid/uuid.dart';

import '../app_context.dart';
import '../common/time_slice.dart';
import '../styles.dart';
import '../widgets/gg_icon_button.dart';
import 'flattened_goal_tree.dart';
import 'goal_actions_context.dart';
import 'hover_actions.dart';
import 'providers.dart';

class ScheduledGoalsV2 extends ConsumerStatefulWidget {
  final Map<String, Goal> goalMap;
  final List<String> path;
  const ScheduledGoalsV2({
    super.key,
    required this.goalMap,
    this.path = const [],
  });

  @override
  ConsumerState<ScheduledGoalsV2> createState() => _ScheduledGoalsV2State();
}

const EXPANDED_TIME_SLICES_KEY = 'ScheduledGoals.expandedTimeSlices';

class _ScheduledGoalsV2State extends ConsumerState<ScheduledGoalsV2> {
  Set<TimeSlice> _expandedTimeSlices = {TimeSlice.today};

  @override
  void initState() {
    super.initState();

    final List<String> expandedTimeSlices = (Hive.box('goals_web.ui')
                .get(EXPANDED_TIME_SLICES_KEY, defaultValue: <String>['today'])
            as List<dynamic>)
        .cast();

    setState(() {
      _expandedTimeSlices = expandedTimeSlices
          .map((e) => TimeSlice.values.firstWhere((slice) => slice.name == e))
          .toSet();
    });
  }

  _toggleExpansion(TimeSlice slice) {
    setState(() {
      if (_expandedTimeSlices.contains(slice)) {
        _expandedTimeSlices.remove(slice);
      } else {
        _expandedTimeSlices.add(slice);
      }
      Hive.box('goals_web.ui').put(EXPANDED_TIME_SLICES_KEY,
          _expandedTimeSlices.map((e) => e.name).toList());
    });
  }

  Widget _smallSlice(WorldContext worldContext, TimeSlice slice,
      Map<String, Goal> sliceGoalMap, DragEventType? dragEventType) {
    return Container(
      child: DragTarget<GoalDragDetails>(
        onAcceptWithDetails: (details) {
          if (dragEventProvider.value == DragEventType.start &&
              !sliceGoalMap.containsKey(details.data.path.goalId)) {
            final goal = widget.goalMap[details.data.path.goalId];

            if (goal == null) {
              return;
            }

            final goalStatus = getGoalStatus(worldContext, goal);

            if (slice == TimeSlice.unscheduled) {
              AppContext.of(this.context).syncClient.modifyGoal(GoalDelta(
                  id: details.data.path.goalId,
                  logEntry: StatusLogEntry(
                    id: const Uuid().v4(),
                    creationTime: DateTime.now(),
                    status: null,
                    startTime: slice.startTime(worldContext.time),
                    endTime: slice.endTime(worldContext.time),
                  )));
              return;
            }

            final sliceStartTime = slice.startTime(worldContext.time);
            final sliceEndTime = slice.endTime(worldContext.time);

            // This is for the special case where a goal has an active status with a specific end date
            // and we're moving it into a smaller time slice (e.g. from This Month to This Week).
            // In this case, we want to keep the end date the same.
            final newEndTime = goalStatus.status == GoalStatus.active &&
                    (sliceStartTime == null ||
                        goalStatus.startTime?.isBefore(sliceStartTime) ==
                            true) &&
                    (sliceEndTime == null ||
                        goalStatus.endTime?.isBefore(sliceEndTime) == true)
                ? goalStatus.endTime
                : sliceEndTime;

            AppContext.of(this.context).syncClient.modifyGoal(GoalDelta(
                id: details.data.path.goalId,
                logEntry: StatusLogEntry(
                  id: const Uuid().v4(),
                  creationTime: DateTime.now(),
                  status: GoalStatus.active,
                  startTime: slice.startTime(worldContext.time),
                  endTime: newEndTime,
                )));
          }
        },
        builder: (BuildContext context, List<Object?> candidateData,
            List<dynamic> _) {
          return Container(
            decoration: BoxDecoration(
              color:
                  candidateData.isNotEmpty ? emphasizedLightBackground : null,
              border: candidateData.isNotEmpty
                  ? Border(
                      top: BorderSide(
                        color: darkElementColor,
                        width: 2.0,
                      ),
                      bottom: BorderSide(
                        color: darkElementColor,
                        width: 2.0,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                          vertical: candidateData.isNotEmpty
                              ? uiUnit() - 2
                              : uiUnit())
                      .copyWith(left: uiUnit(2)),
                  child: Text(
                    slice.displayName,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: dragEventType != DragEventType.start ||
                                  sliceGoalMap.isNotEmpty ||
                                  candidateData.isNotEmpty
                              ? Theme.of(context).textTheme.headlineSmall!.color
                              : Theme.of(context)
                                  .textTheme
                                  .headlineSmall!
                                  .color!
                                  .withOpacity(0.5),
                        ),
                  ),
                ),
                GlassGoalsIconButton(
                  icon: Icons.arrow_right,
                  onPressed: () {
                    this._toggleExpansion(slice);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _timeSlices(WorldContext worldContext, List<TimeSlice> slices,
      [List<TimeSlice>? manualTimeSlices, DragEventType? dragEventType]) {
    final Map<String, Goal> goalsAccountedFor = {};
    final List<Widget> result = [];
    Widget? unscheduledSlice;
    for (final slice in slices) {
      final sliceGoalMap = slice == TimeSlice.unscheduled
          ? getGoalsRequiringAttention(worldContext, widget.goalMap)
          : getGoalsForDateRange(
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
        goalsAccountedFor
            .addAll(getTransitiveSubGoals(widget.goalMap, goal.id));
      }

      final goalIds = sliceGoalMap.values
          .where((goal) {
            for (final superGoalId in goal.superGoalIds) {
              if (sliceGoalMap.containsKey(superGoalId)) {
                return false;
              }
            }
            return true;
          })
          .map((e) => e.id)
          .toList();

      if (goalIds.isEmpty &&
          (manualTimeSlices == null || !manualTimeSlices.contains(slice)) &&
          slice != TimeSlice.unscheduled &&
          dragEventType != DragEventType.start) {
        continue;
      }

      if (_expandedTimeSlices.contains(slice) &&
          (goalIds.isNotEmpty || slice == TimeSlice.unscheduled)) {
        final sliceWidget = Padding(
          padding: EdgeInsets.only(bottom: uiUnit(3)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: uiUnit())
                          .copyWith(left: uiUnit(2)),
                      child: Text(
                        slice.displayName,
                        style:
                            Theme.of(context).textTheme.headlineSmall!.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    GlassGoalsIconButton(
                      icon: Icons.arrow_drop_down,
                      onPressed: () {
                        this._toggleExpansion(slice);
                      },
                    ),
                  ],
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
                      droppedGoalPath, {
                      List<String>? dropPath,
                      List<String>? prevDropPath,
                      List<String>? nextDropPath,
                    }) {
                      onDropGoal(
                        droppedGoalPath,
                        dropPath: dropPath,
                        prevDropPath: prevDropPath,
                        nextDropPath: nextDropPath,
                      );
                      final selectedGoals = selectedGoalsStream.value;
                      final goalsToUpdate =
                          selectedGoals.contains(droppedGoalPath)
                              ? selectedGoals
                              : {droppedGoalPath};
                      bool setNullParent =
                          goalsToUpdate.every(sliceGoalMap.containsKey);
                      bool addStatus = goalsToUpdate.every(
                              (goalId) => !sliceGoalMap.containsKey(goalId)) &&
                          slice != TimeSlice.unscheduled;
                      for (final path in goalsToUpdate) {
                        final goal = widget.goalMap[path.goalId];

                        if (goal == null) {
                          continue;
                        }

                        if (addStatus) {
                          final goalStatus = getGoalStatus(worldContext, goal);

                          final sliceStartTime =
                              slice.startTime(worldContext.time);
                          final sliceEndTime = slice.endTime(worldContext.time);

                          // This is for the special case where a goal has an active status with a specific end date
                          // and we're moving it into a smaller time slice (e.g. from This Month to This Week).
                          // In this case, we want to keep the end date the same.
                          final newEndTime =
                              goalStatus.status == GoalStatus.active &&
                                      (sliceStartTime == null ||
                                          goalStatus.startTime
                                                  ?.isBefore(sliceStartTime) ==
                                              true) &&
                                      (sliceEndTime == null ||
                                          goalStatus.endTime
                                                  ?.isBefore(sliceEndTime) ==
                                              true)
                                  ? goalStatus.endTime
                                  : sliceEndTime;

                          AppContext.of(this.context)
                              .syncClient
                              .modifyGoal(GoalDelta(
                                  id: path.goalId,
                                  logEntry: StatusLogEntry(
                                    id: const Uuid().v4(),
                                    creationTime: DateTime.now(),
                                    status: GoalStatus.active,
                                    startTime:
                                        slice.startTime(worldContext.time),
                                    endTime: newEndTime,
                                  )));
                        }

                        if (setNullParent &&
                            (prevDropPath?.length == 1 ||
                                prevDropPath?.length == 2) &&
                            (nextDropPath?.length == 1 ||
                                nextDropPath?.length == 2)) {
                          AppContext.of(this.context).syncClient.modifyGoal(
                              GoalDelta(
                                  id: path.goalId,
                                  logEntry: SetParentLogEntry(
                                      id: const Uuid().v4(),
                                      parentId: null,
                                      creationTime: DateTime.now())));
                        }
                      }
                    },
                    child: FlattenedGoalTree(
                      goalMap: sliceGoalMap,
                      rootGoalIds: goalIds,
                      path: GoalPath([...widget.path, "slice:${slice.name}"]),
                      hoverActionsBuilder: (path) => HoverActionsWidget(
                        path: path,
                        goalMap: widget.goalMap,
                      ),
                    ),
                  );
                })
              ]),
        );
        if (slice == TimeSlice.unscheduled) {
          unscheduledSlice = sliceWidget;
        } else {
          result.add(sliceWidget);
        }
      } else {
        final sliceWidget =
            _smallSlice(worldContext, slice, sliceGoalMap, dragEventType);
        if (slice == TimeSlice.unscheduled) {
          unscheduledSlice = sliceWidget;
        } else {
          result.add(sliceWidget);
        }
      }
    }
    if (unscheduledSlice != null) {
      result.insert(0, unscheduledSlice);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;
    final manualTimeSlices = ref.watch(manualTimeSliceProvider);
    final dragEventType = ref.watch(dragEventProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._timeSlices(
          worldContext,
          [
            TimeSlice.today,
            TimeSlice.this_week,
            TimeSlice.this_month,
            TimeSlice.this_quarter,
            TimeSlice.this_year,
            TimeSlice.long_term,
            TimeSlice.unscheduled,
          ],
          manualTimeSlices.value,
          dragEventType,
        )
      ],
    );
  }
}
