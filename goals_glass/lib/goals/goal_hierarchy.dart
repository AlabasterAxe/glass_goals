import 'dart:developer';

import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        Hero,
        Navigator,
        PageController,
        Positioned,
        Stack,
        State,
        StatefulWidget,
        ValueKey,
        Widget;
import 'package:goals_core/model.dart' show Goal, WorldContext, getGoalStatus;
import 'package:goals_core/sync.dart'
    show GoalDelta, GoalStatus, SetParentLogEntry;
import 'package:uuid/uuid.dart';

import '../util/app_context.dart';
import '../util/glass_gesture_detector.dart';
import '../util/glass_page_view.dart';
import 'add_subgoal_card.dart';
import 'goal_card.dart';
import 'goal_title.dart';

class GoalHierarchy extends StatefulWidget {
  final Map<String, Goal> goalState;
  final String rootGoalId;

  const GoalHierarchy(this.goalState, {super.key, required this.rootGoalId});

  @override
  State<GoalHierarchy> createState() => _GoalHierarchyState();
}

class _GoalHierarchyState extends State<GoalHierarchy> {
  late String _activeGoalId;
  late PageController _pageController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _activeGoalId = widget.rootGoalId;
    _pageController = PageController();
  }

  onBack() {
    final activeGoal = widget.goalState[_activeGoalId];
    if (activeGoal == null) {
      setState(() {
        _activeGoalId = 'root';
      });
      return;
    }
    if (activeGoal.superGoals.isNotEmpty) {
      final parentGoal = widget.goalState[activeGoal.superGoals.first];
      int? childPage;
      if (parentGoal == null) {
        return;
      }
      childPage = parentGoal.subGoals
          .indexWhere((subGoal) => subGoal.id == activeGoal.id);

      setState(() {
        _activeGoalId = parentGoal.id;
        if (childPage != null) {
          _pageController.jumpToPage(childPage);
        }
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeGoal =
        widget.goalState[_activeGoalId] ?? widget.goalState['root']!;
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
          controller: _pageController,
          children: [
            ...activeGoal.subGoals
                .where((subGoal) => ![GoalStatus.archived, GoalStatus.done]
                    .contains(
                        getGoalStatus(WorldContext.now(), subGoal).status))
                .map((subGoal) => GoalCard(
                    key: ValueKey(subGoal.id),
                    goal: subGoal,
                    onTap: () {
                      setState(() {
                        // TODO: preserve scroll position?
                        _pageController.jumpToPage(0);
                        _activeGoalId = subGoal.id;
                      });
                    },
                    onBack: onBack))
                .toList(),
            GlassGestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 10) {
                  onBack();
                }
              },
              child: AddSubGoalCard(onGoalText: (text) {
                setState(() {
                  AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                      id: const Uuid().v4(),
                      text: text,
                      logEntry: SetParentLogEntry(
                          creationTime: DateTime.now(),
                          id: const Uuid().v4(),
                          parentId: activeGoal.id)));
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
