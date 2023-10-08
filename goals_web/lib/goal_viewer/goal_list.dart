import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/widgets.dart'
    show BuildContext, Column, Container, StatelessWidget, Widget;
import 'package:goals_core/model.dart' show Goal;

import 'add_subgoal_item.dart';
import 'goal_tree.dart' show GoalTreeWidget;

class GoalListWidget extends StatefulWidget {
  final Map<String, Goal> goalMap;
  final List<String> goalIds;
  final Function(String goalId) onSelected;
  final Function(String goalId, {bool expanded}) onExpanded;
  final Function(String goalId) onFocused;
  final int? depthLimit;
  final bool showAddGoal;
  final Widget hoverActions;
  const GoalListWidget({
    super.key,
    required this.goalMap,
    required this.goalIds,
    required this.onSelected,
    required this.onExpanded,
    required this.onFocused,
    required this.hoverActions,
    this.depthLimit,
    this.showAddGoal = false,
  });

  @override
  State<GoalListWidget> createState() => _GoalListWidgetState();
}

class _GoalListWidgetState extends State<GoalListWidget> {
  bool _addingGoal = false;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final goalId in widget.goalIds)
            GoalTreeWidget(
              goalMap: widget.goalMap,
              rootGoalId: goalId,
              onSelected: widget.onSelected,
              onExpanded: widget.onExpanded,
              onFocused: widget.onFocused,
              depthLimit: widget.depthLimit,
              showParentName: true,
              hoverActions: widget.hoverActions,
              onEnter: () {
                print("!!!");
                setState(() {
                  _addingGoal = true;
                });
              },
            ),
          _addingGoal ? const AddSubgoalItemWidget() : Container(),
        ],
      );
}
