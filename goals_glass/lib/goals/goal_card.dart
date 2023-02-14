import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Column,
        Container,
        EdgeInsets,
        Hero,
        MainAxisAlignment,
        Navigator,
        Padding,
        StatelessWidget,
        Text,
        Widget;
import 'package:goals_core/model.dart' show Goal, WorldContext, goalHasStatus;
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, StatusLogEntry;

import '../styles.dart' show subTitleStyle;
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
                            AppContext.of(context)
                                .syncClient
                                .modifyGoal(GoalDelta(
                                    id: goal.id,
                                    statusLogEntry: StatusLogEntry(
                                      status: GoalStatus.archived,
                                      creationTime: DateTime.now(),
                                    )));
                          },
                          onSetActive: () {
                            AppContext.of(context).syncClient.modifyGoal(
                                GoalDelta(
                                    id: goal.id,
                                    statusLogEntry: StatusLogEntry(
                                        status: GoalStatus.active,
                                        creationTime: DateTime.now(),
                                        startTime: DateTime.now(),
                                        endTime: goalHasStatus(
                                                    WorldContext.now(),
                                                    goal,
                                                    GoalStatus.active) !=
                                                null
                                            ? DateTime.now()
                                            : endOfDay(DateTime.now()))));
                          },
                        ))));
          }
        },
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Hero(tag: goal.id, child: GoalTitle(goal)),
            goalHasStatus(WorldContext.now(), goal, GoalStatus.active) != null
                ? const Text('Active', style: subTitleStyle)
                : Container()
          ]),
        ));
  }
}
