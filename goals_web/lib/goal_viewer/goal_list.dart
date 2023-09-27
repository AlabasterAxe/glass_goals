import 'package:flutter/widgets.dart'
    show BuildContext, Column, StatelessWidget, Widget;
import 'package:goals_core/model.dart' show Goal;

import 'goal_tree.dart' show GoalTreeWidget;

class GoalListWidget extends StatelessWidget {
  final Map<String, Goal> goalMap;
  final List<String> goalIds;
  final Function(String goalId) onSelected;
  final Function(String goalId, {bool expanded}) onExpanded;
  final int? depthLimit;
  const GoalListWidget({
    super.key,
    required this.goalMap,
    required this.goalIds,
    required this.onSelected,
    required this.onExpanded,
    this.depthLimit,
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
              depthLimit: depthLimit,
              showParentName: true,
            ),
        ],
      );
}
