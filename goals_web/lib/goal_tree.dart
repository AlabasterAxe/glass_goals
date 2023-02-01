import 'package:flutter/widgets.dart'
    show BuildContext, StatelessWidget, Widget, Placeholder;
import 'package:goals_core/model.dart' show Goal;

class GoalTreeWidget extends StatelessWidget {
  final Map<String, Goal> goalMap;
  final String rootGoalId;
  const GoalTreeWidget(
      {super.key, required this.goalMap, required this.rootGoalId});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
