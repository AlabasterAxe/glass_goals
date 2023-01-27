import 'dart:developer' show log;

import 'package:flutter/material.dart'
    show Colors, MaterialPageRoute, Navigator, Theme;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        Container,
        Hero,
        PageView,
        Positioned,
        Stack,
        State,
        StatefulWidget,
        StatelessWidget,
        Text,
        TextStyle,
        Widget;
import 'package:glass_goals/sync/ops.dart' show GoalDelta;
import 'package:glass_goals/util/glass_gesture_detector.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'app_context.dart' show AppContext;
import 'util/glass_scaffold.dart';
import 'model.dart' show Goal;
import 'styles.dart' show mainTextStyle;

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
  const GoalMenu({super.key, required this.onArchive});

  @override
  Widget build(BuildContext context) {
    return GlassGestureDetector(
        onTap: () {
          onArchive();
          Navigator.pop(context);
        },
        child: Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(child: Text('Archive', style: mainTextStyle))));
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
            child: PageView(
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
                                        child: GoalMenu(onArchive: () {
                                      setState(() {
                                        AppContext.of(context)
                                            .syncClient
                                            .modifyGoal(GoalDelta(
                                                id: subGoal.id,
                                                parentId: 'archive'));
                                      });
                                    }))));
                      }
                    },
                    onTap: () {
                      setState(() {
                        activeGoalId = subGoal.id;
                      });
                    },
                    child: Hero(tag: subGoal.id, child: GoalTitle(subGoal))))
                .toList(),
            AddSubGoalCard(onGoalText: (text) {
              setState(() {
                AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                    id: const Uuid().v4(),
                    text: text,
                    parentId: activeGoal.id));
              });
            }, onError: (e) {
              log(e.toString());
            }),
          ],
        )),
      ],
    );
  }
}
