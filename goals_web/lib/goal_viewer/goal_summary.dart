import 'package:flutter/material.dart' show Theme;
import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show BuildContext, StatelessWidget, Text, Widget;
import 'package:goals_core/model.dart' show Goal, hasSummary;
import 'package:goals_web/goal_viewer/goal_breadcrumb.dart';
import 'package:goals_web/goal_viewer/goal_note.dart';
import 'package:goals_web/styles.dart';

class GoalSummary extends StatelessWidget {
  final Goal goal;
  final Map<String, Goal> goalMap;
  const GoalSummary({super.key, required this.goal, required this.goalMap});

  @override
  Widget build(BuildContext context) {
    final goalSummary = hasSummary(goal);

    final colChildren = <Widget>[];

    if (goalSummary != null) {
      colChildren.add(NoteCard(
        goal: this.goal,
        summaryEntry: goalSummary,
        onRefresh: () => {},
        isChildGoal: false,
        showTime: false,
      ));
    }

    final indent = uiUnit(4);
    for (final childId in goal.subGoalIds) {
      final childGoal = goalMap[childId];
      if (childGoal != null) {
        final childSummary = hasSummary(childGoal);
        if (childSummary != null) {
          colChildren.add(
            Padding(
                padding: EdgeInsets.only(left: indent),
                child: Breadcrumb(
                    goal: childGoal,
                    style: Theme.of(context).textTheme.headlineSmall)),
          );

          colChildren.add(Padding(
            padding: EdgeInsets.only(left: indent),
            child: NoteCard(
              goal: childGoal,
              summaryEntry: childSummary,
              onRefresh: () => {},
              isChildGoal: true,
              showTime: false,
            ),
          ));
        }
      }
    }

    return Column(
      children: colChildren,
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }
}
