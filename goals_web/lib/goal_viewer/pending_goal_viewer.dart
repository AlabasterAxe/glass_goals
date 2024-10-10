import 'package:flutter/material.dart';
import 'package:goals_core/model.dart'
    show Goal, GoalPath, getGoalStatus, getGoalsMatchingPredicate;
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/flattened_goal_tree.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:goals_web/goal_viewer/scheduled_goals_v2.dart';
import 'package:goals_web/styles.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const PENDING_GOAL_VIEW_MODE_PREFIX = 'PendingGoalViewer.viewMode';

final viewModeBoxKey =
    (String viewKey) => '${PENDING_GOAL_VIEW_MODE_PREFIX}.${viewKey}';

class PendingGoalViewModePicker extends StatefulWidget {
  final Function(PendingGoalViewMode) onModeChanged;
  final PendingGoalViewMode mode;
  final bool showInfo;
  const PendingGoalViewModePicker({
    super.key,
    required this.onModeChanged,
    required this.mode,
    this.showInfo = false,
  });

  @override
  State<PendingGoalViewModePicker> createState() =>
      _PendingGoalViewModePickerState();
}

class _PendingGoalViewModePickerState extends State<PendingGoalViewModePicker> {
  @override
  Widget build(BuildContext context) {
    return DropdownButton<PendingGoalViewMode>(
      items: [
        DropdownMenuItem<PendingGoalViewMode>(
            child: Text('Tree'), value: PendingGoalViewMode.tree),
        DropdownMenuItem<PendingGoalViewMode>(
            child: Text('Schedule'), value: PendingGoalViewMode.schedule),
      ],
      borderRadius: BorderRadius.circular(uiUnit(1)),
      padding: EdgeInsets.symmetric(horizontal: uiUnit(2)),
      value: this.widget.mode,
      onChanged: (mode) {
        if (mode == null) {
          return;
        }
        this.widget.onModeChanged(mode);
      },
    );
  }
}

class PendingGoalViewer extends ConsumerWidget {
  final Map<String, Goal> goalMap;
  final PendingGoalViewMode mode;
  final GoalPath path;

  const PendingGoalViewer({
    super.key,
    required this.goalMap,
    required this.mode,
    required this.path,
  });

  @override
  Widget build(BuildContext context, ref) {
    final worldContext =
        ref.read(worldContextProvider).value ?? worldContextStream.value;
    return switch (this.mode) {
      PendingGoalViewMode.schedule =>
        ScheduledGoalsV2(goalMap: this.goalMap, path: this.path),
      PendingGoalViewMode.tree => FlattenedGoalTree(
          path: this.path,
          goalMap: getGoalsMatchingPredicate(
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
                for (final superGoalId in goal.superGoalIds) {
                  if (this.goalMap.containsKey(superGoalId)) {
                    return false;
                  }
                }
                return true;
              })
              .map((e) => e.id)
              .toList(),
          hoverActionsBuilder: (path) =>
              HoverActionsWidget(path: path, goalMap: this.goalMap),
        ),
    };
  }
}

enum PendingGoalViewMode {
  // schedule view breaks the goals into sections based on their currently active status
  schedule,

  // tree view just shows the goals in a tree format
  tree,
}
