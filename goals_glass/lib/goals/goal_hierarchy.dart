import 'dart:developer';

import 'package:flutter/material.dart' show Column, MaterialPageRoute;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        Container,
        Hero,
        MainAxisAlignment,
        Navigator,
        Positioned,
        Stack,
        State,
        StatefulWidget,
        Text,
        Widget;
import 'package:goals_core/model.dart' show Goal, isGoalActive;
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, StatusLogEntry;
import 'package:uuid/uuid.dart';

import '../util/app_context.dart';
import '../util/glass_gesture_detector.dart';
import '../util/glass_page_view.dart';
import '../util/glass_scaffold.dart';
import 'add_subgoal_card.dart';
import 'goal_menu.dart';
import 'goal_title.dart';

DateTime endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59);
}

class GoalsWidget extends StatefulWidget {
  final Map<String, Goal> goalState;
  final String rootGoalId;

  const GoalsWidget(this.goalState, {super.key, required this.rootGoalId});

  @override
  State<GoalsWidget> createState() => _GoalsWidgetState();
}

class _GoalsWidgetState extends State<GoalsWidget> {
  late String activeGoalId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    activeGoalId = widget.rootGoalId;
  }

  @override
  Widget build(BuildContext context) {
    final activeGoal = widget.goalState[activeGoalId]!;
    return Stack(
      children: [
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Center(
                child: Hero(
              tag: activeGoal.id,
              child: GoalTitle(activeGoal),
            ))),
        Positioned.fill(
            child: GlassPageView(
          children: [
            ...activeGoal.subGoals
                .map((subGoal) => GlassGestureDetector(
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! > 10) {
                        if (activeGoal.parentId != null) {
                          setState(() {
                            activeGoalId = activeGoal.parentId!;
                          });
                        } else {
                          Navigator.pop(context);
                        }
                      }
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < -10) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => GlassScaffold(
                                        child: GoalMenu(
                                      goal: subGoal,
                                      onArchive: () {
                                        setState(() {
                                          AppContext.of(context)
                                              .syncClient
                                              .modifyGoal(GoalDelta(
                                                  id: subGoal.id,
                                                  parentId: 'archive'));
                                        });
                                      },
                                      onSetActive: () {
                                        AppContext.of(context)
                                            .syncClient
                                            .modifyGoal(GoalDelta(
                                                id: subGoal.id,
                                                statusLogEntry: StatusLogEntry(
                                                    status: GoalStatus.active,
                                                    startTime: DateTime.now(),
                                                    endTime: isGoalActive(
                                                                subGoal) !=
                                                            null
                                                        ? DateTime.now()
                                                        : endOfDay(
                                                            DateTime.now()))));
                                      },
                                    ))));
                      }
                    },
                    onTap: () {
                      setState(() {
                        activeGoalId = subGoal.id;
                      });
                    },
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Hero(tag: subGoal.id, child: GoalTitle(subGoal)),
                          isGoalActive(subGoal) != null
                              ? const Text('Active')
                              : Container()
                        ])))
                .toList(),
            GlassGestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 10) {
                  if (activeGoal.parentId != null) {
                    setState(() {
                      activeGoalId = activeGoal.parentId!;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                }
              },
              child: AddSubGoalCard(onGoalText: (text) {
                setState(() {
                  AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                      id: const Uuid().v4(),
                      text: text,
                      parentId: activeGoal.id));
                });
              }, onError: (e) {
                log(e.toString());
              }),
            ),
          ],
        )),
      ],
    );
  }
}
