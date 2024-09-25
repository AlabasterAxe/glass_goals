import 'package:flutter/widgets.dart'
    show BuildContext, Container, StatelessWidget, Widget;
import 'package:goals_core/model.dart' show Goal, hasSummary;
import 'package:goals_web/goal_viewer/goal_note.dart';

class GoalSummary extends StatelessWidget {
  final Goal goal;
  const GoalSummary({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final goalSummary = hasSummary(goal);

    if (goalSummary == null) {
      return Container();
    }

    return NoteCard(
      goal: this.goal,
      summaryEntry: goalSummary,
      onRefresh: () => {},
      isChildGoal: false,
      showTime: false,
    );
  }
}
