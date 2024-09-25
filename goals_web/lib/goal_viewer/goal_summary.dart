import 'package:flutter/material.dart' show Theme;
import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart' show BuildContext, Widget;
import 'package:goals_core/model.dart'
    show Goal, getPriorityComparator, hasSummary;
import 'package:goals_web/goal_viewer/goal_breadcrumb.dart';
import 'package:goals_web/goal_viewer/goal_note.dart';
import 'package:goals_web/goal_viewer/providers.dart'
    show worldContextProvider, worldContextStream;
import 'package:goals_web/styles.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerWidget, WidgetRef;

import 'package:collection/collection.dart' show IterableExtension;

class GoalSummary extends ConsumerWidget {
  final Goal goal;
  final Map<String, Goal> goalMap;
  const GoalSummary({super.key, required this.goal, required this.goalMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalSummary = hasSummary(goal);
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;
    final comparator = getPriorityComparator(worldContext);

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
    for (final childGoal in goal.subGoalIds
        .map((id) => goalMap[id])
        .whereType<Goal>()
        .sorted(comparator)) {
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

    return Column(
      children: colChildren,
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }
}
