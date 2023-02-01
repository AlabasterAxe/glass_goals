import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        SingleChildScrollView,
        Spacer,
        StatelessWidget,
        Text,
        Widget;
import 'package:goals_core/model.dart' show Goal;

class GoalTreeWidget extends StatelessWidget {
  final Map<String, Goal> goalMap;
  final String rootGoalId;
  const GoalTreeWidget(
      {super.key, required this.goalMap, required this.rootGoalId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goalMap[rootGoalId]!.text),
          Row(children: [
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final goal in goalMap[rootGoalId]!.subGoals)
                GoalTreeWidget(goalMap: goalMap, rootGoalId: goal.id),
            ])
          ])
        ],
      ),
    );
  }
}
