import 'package:flutter/widgets.dart'
    show BuildContext, Column, StatelessWidget, Widget;
import 'package:goals_core/model.dart' show Goal;

import 'goal_tree.dart' show GoalTreeWidget;

class GoalListWidget extends StatelessWidget {
  final Map<String, Goal> goalMap;
  final List<String> goalIds;
  final Set<String> selectedGoals;
  final Function(String goalId) onSelected;
  final Set<String> expandedGoals;
  final Function(String goalId, {bool expanded}) onExpanded;
  const GoalListWidget({
    super.key,
    required this.goalMap,
    required this.goalIds,
    required this.selectedGoals,
    required this.onSelected,
    required this.expandedGoals,
    required this.onExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final goalId in goalIds)
          GoalTreeWidget(
            goalMap: goalMap,
            rootGoalId: goalId,
            selectedGoals: selectedGoals,
            onSelected: onSelected,
            expandedGoals: expandedGoals,
            onExpanded: onExpanded,
            depthLimit: 1,
            showParentName: true,
          ),
      ],
    );
  }
}
