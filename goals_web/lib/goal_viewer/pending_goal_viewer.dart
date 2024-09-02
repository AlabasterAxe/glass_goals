import 'package:flutter/material.dart';
import 'package:goals_core/model.dart'
    show Goal, getGoalStatus, getGoalsMatchingPredicate;
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/flattened_goal_tree.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/goal_viewer/scheduled_goals_v2.dart';
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const PENDING_GOAL_VIEW_MODE_PREFIX = 'PendingGoalViewer.viewMode';

final _boxKey =
    (String viewKey) => '${PENDING_GOAL_VIEW_MODE_PREFIX}.${viewKey}';

class PendingGoalViewModePicker extends StatefulWidget {
  final Function(PendingGoalViewMode) onModeChanged;
  final String viewKey;
  const PendingGoalViewModePicker(
      {super.key, required this.onModeChanged, required this.viewKey});

  @override
  State<PendingGoalViewModePicker> createState() =>
      _PendingGoalViewModePickerState();
}

class _PendingGoalViewModePickerState extends State<PendingGoalViewModePicker> {
  PendingGoalViewMode _viewMode = PendingGoalViewMode.schedule;

  @override
  void initState() {
    super.initState();

    Hive.openBox('goals_web.ui').then((box) {
      final viewModeString = box.get(_boxKey(this.widget.viewKey),
          defaultValue: PendingGoalViewMode.schedule.name);

      try {
        _viewMode = PendingGoalViewMode.values.byName(viewModeString);
        this.widget.onModeChanged(_viewMode);
        setState(() {});
      } catch (_) {
        // use default value
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PendingGoalViewMode>(
      segments: [
        ButtonSegment<PendingGoalViewMode>(
            label: Text('Schedule'), value: PendingGoalViewMode.schedule),
        ButtonSegment<PendingGoalViewMode>(
            label: Text('Tree'), value: PendingGoalViewMode.tree),
      ],
      selected: {this._viewMode},
      onSelectionChanged: (modes) {
        this._viewMode = modes.first;
        this.widget.onModeChanged(this._viewMode);
        Hive.openBox('goals_web.ui').then((box) {
          box.put(_boxKey(this.widget.viewKey), modes.first.name);
        });
      },
    );
  }
}

class PendingGoalViewer extends ConsumerWidget {
  final Map<String, Goal> goalMap;
  final String viewKey;
  final PendingGoalViewMode mode;

  const PendingGoalViewer(
      {super.key,
      required this.goalMap,
      required this.viewKey,
      required this.mode});

  @override
  Widget build(BuildContext context, ref) {
    final worldContext = ref.read(worldContextProvider).value!;
    return switch (this.mode) {
      // TODO: Handle this case.
      PendingGoalViewMode.schedule => ScheduledGoalsV2(goalMap: this.goalMap),
      PendingGoalViewMode.tree => FlattenedGoalTree(
          goalMap: getGoalsMatchingPredicate(
              worldContext,
              this.goalMap,
              (goal) => ![
                    GoalStatus.done,
                    GoalStatus.archived,
                    GoalStatus.pending
                  ].contains(getGoalStatus(worldContext, goal).status)),
          rootGoalIds: this
              .goalMap
              .values
              .where((goal) {
                if ([
                  GoalStatus.done,
                  GoalStatus.archived,
                  GoalStatus.pending,
                ].contains(getGoalStatus(worldContext, goal).status)) {
                  return false;
                }
                for (final superGoal in goal.superGoals) {
                  if (this.goalMap.containsKey(superGoal.id)) {
                    return false;
                  }
                }
                return true;
              })
              .map((e) => e.id)
              .toList(),
          hoverActionsBuilder: (goalId) =>
              HoverActionsWidget(goalId: goalId, goalMap: this.goalMap),
          section: this.viewKey),
    };
  }
}

enum PendingGoalViewMode {
  schedule,
  tree,
}
