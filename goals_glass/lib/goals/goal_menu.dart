import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Center,
        Container,
        Navigator,
        StatelessWidget,
        Text,
        Widget;
import 'package:goals_core/model.dart' show Goal, WorldContext, goalHasStatus;
import 'package:goals_core/sync.dart';
import 'package:uuid/uuid.dart';

import '../styles.dart';
import '../util/app_context.dart';
import '../util/glass_gesture_detector.dart';
import '../util/glass_page_view.dart';
import 'add_subgoal_card.dart';

class GoalMenu extends StatelessWidget {
  final void Function() onArchive;
  final void Function() onSetActive;
  final void Function() onDone;
  final Goal goal;
  const GoalMenu({
    super.key,
    required this.onArchive,
    required this.onSetActive,
    required this.onDone,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      GlassGestureDetector(
        onTap: () {
          onSetActive();
          Navigator.pop(context);
        },
        child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
                child: Text(
                    goalHasStatus(
                                WorldContext.now(), goal, GoalStatus.active) !=
                            null
                        ? 'Deactivate'
                        : 'Activate',
                    style: mainTextStyle))),
      ),
      GlassGestureDetector(
        onTap: () {
          onDone();
          Navigator.pop(context);
        },
        child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
                child: Text(
                    goalHasStatus(WorldContext.now(), goal, GoalStatus.done) !=
                            null
                        ? 'Reopen'
                        : 'Mark Complete',
                    style: mainTextStyle))),
      ),
      GlassGestureDetector(
        onTap: () {
          onArchive();
          Navigator.pop(context);
        },
        child: Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(child: Text('Archive', style: mainTextStyle))),
      ),
    ];

    if (goalHasStatus(WorldContext.now(), goal, GoalStatus.active) != null) {
      cards.add(AddSubGoalCard(
        onGoalText: (text) {
          AppContext.of(context).syncClient.modifyGoal(
                GoalDelta(
                  id: const Uuid().v4(),
                  parentId: goal.id,
                  text: text,
                  statusLogEntry: StatusLogEntry(
                    status: GoalStatus.active,
                    creationTime: DateTime.now(),
                    startTime: DateTime.now(),
                    endTime: DateTime.now().add(const Duration(hours: 1)),
                  ),
                ),
              );
        },
        onError: (e) {
          Navigator.pop(context);
        },
      ));
    }
    return GlassPageView(
      children: cards,
    );
  }
}
