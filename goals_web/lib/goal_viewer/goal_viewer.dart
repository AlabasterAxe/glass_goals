import 'package:flutter/material.dart' show ToggleButtons;
import 'package:flutter/widgets.dart';
import 'package:goals_core/model.dart' show Goal;

import 'goal_list.dart' show GoalListWidget;
import 'goal_tree.dart' show GoalTreeWidget;

class GoalViewer extends StatefulWidget {
  final Map<String, Goal> goalMap;
  final String rootGoalId;
  const GoalViewer(
      {super.key, required this.goalMap, required this.rootGoalId});

  @override
  State<GoalViewer> createState() => _GoalViewerState();
}

class _GoalViewerState extends State<GoalViewer> {
  final List<bool> _displayMode = <bool>[true, false];
  final Set<String> selectedGoals = {};
  final Set<String> expandedGoals = {};

  onSelected(String goalId) {
    setState(() {
      if (selectedGoals.contains(goalId)) {
        selectedGoals.remove(goalId);
      } else {
        selectedGoals.add(goalId);
      }
    });
  }

  onExpanded(String goalId) {
    setState(() {
      if (expandedGoals.contains(goalId)) {
        expandedGoals.remove(goalId);
      } else {
        expandedGoals.add(goalId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: SingleChildScrollView(
          child: _displayMode[0]
              ? GoalTreeWidget(
                  goalMap: widget.goalMap,
                  rootGoalId: widget.rootGoalId,
                  selectedGoals: selectedGoals,
                  onSelected: onSelected,
                  expandedGoals: expandedGoals,
                  onExpanded: onExpanded,
                )
              : GoalListWidget(
                  goalMap: widget.goalMap,
                  selectedGoals: selectedGoals,
                  onSelected: onSelected,
                  expandedGoals: expandedGoals,
                  onExpanded: onExpanded,
                ),
        ),
      ),
      ToggleButtons(
        direction: Axis.horizontal,
        onPressed: (index) {
          setState(() {
            for (int i = 0; i < _displayMode.length; i++) {
              _displayMode[i] = i == index;
            }
          });
        },
        isSelected: _displayMode,
        children: const [
          Text('Tree'),
          Text('List'),
        ],
      ),
    ]);
  }
}
