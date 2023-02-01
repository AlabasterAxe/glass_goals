import 'package:flutter/widgets.dart'
    show BuildContext, Column, StatelessWidget, Widget;
import 'package:goals_core/model.dart' show Goal;

import 'goal_tree.dart' show GoalTreeWidget;

class GoalListWidget extends StatelessWidget {
  final Map<String, Goal> goalMap;
  final Set<String> selectedGoals;
  final Function(String goalId) onSelected;
  final Set<String> expandedGoals;
  final Function(String goalId) onExpanded;
  const GoalListWidget({
    super.key,
    required this.goalMap,
    required this.selectedGoals,
    required this.onSelected,
    required this.expandedGoals,
    required this.onExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final sortedGoals = goalMap.values.toList(growable: false);
    sortedGoals
        .sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
    return Column(
      children: [
        for (final goal in sortedGoals)
          GoalTreeWidget(
            goalMap: goalMap,
            rootGoalId: goal.id,
            selectedGoals: selectedGoals,
            onSelected: onSelected,
            expandedGoals: expandedGoals,
            onExpanded: onExpanded,
            depthLimit: 1,
          ),
      ],
    );
  }
}
