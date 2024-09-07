import 'package:flutter/material.dart';
import 'package:goals_core/model.dart';
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, SetParentLogEntry, StatusLogEntry;
import 'package:goals_web/goal_viewer/goal_detail.dart';
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
import 'package:collection/collection.dart' show IterableExtension;

class ScheduledGoalsV2 extends ConsumerStatefulWidget {
  final Map<String, Goal> goalMap;
  const ScheduledGoalsV2({
    super.key,
    required this.goalMap,
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

    Hive.openBox('goals_web.ui').then((box) {
      final List<String> expandedTimeSlices =
          (box.get(EXPANDED_TIME_SLICES_KEY, defaultValue: <String>['today'])
                  as List<dynamic>)
              .cast();
      setState(() {
        _expandedTimeSlices = expandedTimeSlices
            .map((e) => TimeSlice.values.firstWhere((slice) => slice.name == e))
            .toSet();
      });
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
    return Wrap(
      direction: Axis.horizontal,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: uiUnit())
              .copyWith(left: uiUnit(2)),
          child: Text(
            slice.displayName,
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        GlassGoalsIconButton(
          icon: Icons.arrow_right,
          onPressed: () {
            this._toggleExpansion(slice);
          },
        ),
        for (final goal in goalIds
            .map((id) => sliceGoalMap[id])
            .where((goal) => goal != null)
            .cast<Goal>()
            .sorted(getPriorityComparator(worldContext)))
          if ([GoalStatus.active, null]
              .contains(getGoalStatus(worldContext, goal).status)) ...[
            Text("|"),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: uiUnit(2)),
              child: Breadcrumb(goal: goal),
            ),
          ]
      ],
    );
  }

  List<Widget> _timeSlices(WorldContext worldContext, List<TimeSlice> slices,
      [List<TimeSlice>? manualTimeSlices]) {
    final Map<String, Goal> goalsAccountedFor = {};
    final List<Widget> result = [];
    Widget? unscheduledSlice;
    for (final slice in slices) {
      final sliceGoalMap = slice == TimeSlice.unscheduled
          ? getGoalsMatchingPredicate(
              worldContext,
              widget.goalMap,
              (goal) => [GoalStatus.active, null]
                  .contains(getGoalStatus(worldContext, goal).status))
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

      if (goalIds.isEmpty &&
          (manualTimeSlices == null || !manualTimeSlices.contains(slice)) &&
          slice != TimeSlice.unscheduled) {
        continue;
      }

      if (_expandedTimeSlices.contains(slice)) {
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
                      final selectedGoals = selectedGoalsStream.value;
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
                            (prevDropPath?.length == 1 ||
                                prevDropPath?.length == 2) &&
                            (nextDropPath?.length == 1 ||
                                nextDropPath?.length == 2)) {
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
        final sliceWidget = _smallSlice(worldContext, slice, sliceGoalMap);
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
            manualTimeSlices.value)
      ],
    );
  }
}
