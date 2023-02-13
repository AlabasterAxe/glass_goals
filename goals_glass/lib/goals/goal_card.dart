import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Column,
        Container,
        Hero,
        MainAxisAlignment,
        Navigator,
        StatelessWidget,
        Text,
        Widget;
import 'package:goals_core/model.dart' show Goal, isGoalActive;
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, StatusLogEntry;

import '../util/app_context.dart';
import '../util/glass_gesture_detector.dart';
import '../util/glass_scaffold.dart';
import 'goal_menu.dart';
import 'goal_title.dart';

DateTime endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59);
}

class GoalCard extends StatelessWidget {
  final void Function() onBack;
  final void Function()? onTap;
  final Goal goal;
  const GoalCard(
      {super.key, required this.goal, required this.onBack, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassGestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 10) {
            onBack();
          }
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -10) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => GlassScaffold(
                            child: GoalMenu(
                          goal: goal,
                          onArchive: () {
                            AppContext.of(context).syncClient.modifyGoal(
                                GoalDelta(id: goal.id, parentId: 'archive'));
                          },
                          onSetActive: () {
                            AppContext.of(context).syncClient.modifyGoal(
                                GoalDelta(
                                    id: goal.id,
                                    statusLogEntry: StatusLogEntry(
                                        status: GoalStatus.active,
                                        startTime: DateTime.now(),
                                        endTime: isGoalActive(goal) != null
                                            ? DateTime.now()
                                            : endOfDay(DateTime.now()))));
                          },
                        ))));
          }
        },
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Hero(tag: goal.id, child: GoalTitle(goal)),
          isGoalActive(goal) != null ? const Text('Active') : Container()
        ]));
  }
}
