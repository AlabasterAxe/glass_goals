import 'package:flutter/widgets.dart'
    show BuildContext, Column, Container, StatelessWidget, Widget;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_web/goal_viewer/add_subgoal_item.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart';

import 'goal_tree.dart' show GoalTreeWidget;

class GoalListWidget extends StatelessWidget {
  final Map<String, Goal> goalMap;
  final List<String> goalIds;
  final Function(String goalId) onSelected;
  final Function(String goalId, {bool expanded}) onExpanded;
  final Function(String goalId) onFocused;
  final int? depthLimit;
  final Function(String?, String)? onAddGoal;
  final HoverActionsBuilder hoverActionsBuilder;
  const GoalListWidget({
    super.key,
    required this.goalMap,
    required this.goalIds,
    required this.onSelected,
    required this.onExpanded,
    required this.onFocused,
    required this.hoverActionsBuilder,
    this.depthLimit,
    this.onAddGoal,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final goalId in goalIds)
            GoalTreeWidget(
              goalMap: goalMap,
              rootGoalId: goalId,
              onSelected: onSelected,
              onExpanded: onExpanded,
              onFocused: onFocused,
              depthLimit: depthLimit,
              showParentName: true,
              hoverActionsBuilder: hoverActionsBuilder,
              onAddGoal: onAddGoal,
            ),
          this.onAddGoal != null
              ? AddSubgoalItemWidget(onAddGoal: this.onAddGoal!)
              : Container(),
        ],
      );
}
