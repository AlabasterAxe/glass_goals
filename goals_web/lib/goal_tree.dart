import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Container,
        GestureDetector,
        SingleChildScrollView,
        Spacer,
        StatelessWidget,
        Text,
        Widget;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_web/goal_item.dart';

class GoalTreeWidget extends StatefulWidget {
  final Map<String, Goal> goalMap;
  final String rootGoalId;
  final Set<String> selectedGoals;
  final Function(String goalId) onSelected;
  const GoalTreeWidget({
    super.key,
    required this.goalMap,
    required this.rootGoalId,
    required this.selectedGoals,
    required this.onSelected,
  });

  @override
  State<GoalTreeWidget> createState() => _GoalTreeWidgetState();
}

class _GoalTreeWidgetState extends State<GoalTreeWidget> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final Goal rootGoal = widget.goalMap[widget.rootGoalId]!;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GoalItemWidget(
              goal: rootGoal,
              selected: widget.selectedGoals.contains(rootGoal.id),
              onSelected: (value) {
                widget.onSelected(rootGoal.id);
              }),
          _expanded
              ? Row(children: [
                  const SizedBox(width: 20),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final subGoal in rootGoal.subGoals)
                          GoalTreeWidget(
                            goalMap: widget.goalMap,
                            rootGoalId: subGoal.id,
                            onSelected: widget.onSelected,
                            selectedGoals: widget.selectedGoals,
                          ),
                      ])
                ])
              : Container()
        ],
      ),
    );
  }
}
