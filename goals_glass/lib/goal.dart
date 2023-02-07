import 'dart:developer' show log;

import 'package:flutter/material.dart'
    show Colors, MaterialPageRoute, Navigator, Theme;
import 'package:flutter/rendering.dart' show MainAxisAlignment;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        Column,
        Container,
        Hero,
        Positioned,
        Stack,
        State,
        StatefulWidget,
        StatelessWidget,
        Text,
        TextStyle,
        Widget;
import 'package:uuid/uuid.dart' show Uuid;

import './util/glass_gesture_detector.dart';
import 'util/app_context.dart' show AppContext;
import 'util/glass_page_view.dart' show GlassPageView;
import 'util/glass_scaffold.dart' show GlassScaffold;
import 'package:goals_core/model.dart' show Goal, isGoalActive;
import 'styles.dart' show mainTextStyle;
import 'package:goals_core/sync.dart' show GoalDelta;

class GoalTitle extends StatelessWidget {
  final Goal goal;

  const GoalTitle(this.goal, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        goal.text,
        style: Theme.of(context).textTheme.headline1,
      ),
    );
  }
}

DateTime endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59);
}

class AddSubGoalCard extends StatefulWidget {
  final Function(String) onGoalText;
  final Function(Object) onError;
  const AddSubGoalCard(
      {super.key, required this.onGoalText, required this.onError});

  @override
  State<AddSubGoalCard> createState() => _AddSubGoalCardState();
}

class _AddSubGoalCardState extends State<AddSubGoalCard> {
  @override
  Widget build(BuildContext context) {
    final stt = AppContext.of(context).sttService;

    return GlassGestureDetector(
        onTap: () async {
          try {
            widget.onGoalText(await stt.detectSpeech());
          } catch (e) {
            widget.onError(e);
          }
        },
        child: Center(
            child: Text('+',
                style: mainTextStyle.merge(const TextStyle(fontSize: 100)))));
  }
}

class GoalMenu extends StatelessWidget {
  final void Function() onArchive;
  final void Function() onSetActive;
  final Goal goal;
  const GoalMenu({
    super.key,
    required this.onArchive,
    required this.onSetActive,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPageView(
      children: [
        GlassGestureDetector(
          onTap: () {
            onSetActive();
            Navigator.pop(context);
          },
          child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                  child: Text(isGoalActive(goal) ? 'Deactivate' : 'Activate',
                      style: mainTextStyle))),
        ),
        GlassGestureDetector(
          onTap: () {
            onArchive();
            Navigator.pop(context);
          },
          child: Container(
              color: Colors.black.withOpacity(0.5),
              child:
                  const Center(child: Text('Archive', style: mainTextStyle))),
        ),
      ],
    );
  }
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
                                                activeUntil: isGoalActive(
                                                        subGoal)
                                                    ? DateTime.now()
                                                        .toIso8601String()
                                                    : endOfDay(DateTime.now())
                                                        .toIso8601String()));
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
                          isGoalActive(subGoal) ? Text('Active') : Container()
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
