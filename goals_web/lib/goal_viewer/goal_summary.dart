import 'package:flutter/material.dart' show Icons, Theme;
import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart' show BuildContext, Container, Widget;
import 'package:goals_core/model.dart'
    show
        Goal,
        GoalPath,
        getAllParentContext,
        getPriorityComparator,
        hasParentContext,
        hasSummary;
import 'package:goals_core/sync.dart';
import 'package:goals_web/app_context.dart';
import 'package:goals_web/common/constants.dart';
import 'package:goals_web/goal_viewer/goal_breadcrumb.dart';
import 'package:goals_web/goal_viewer/goal_note.dart';
import 'package:goals_web/goal_viewer/providers.dart'
    show worldContextProvider, worldContextStream;
import 'package:goals_web/styles.dart';
import 'package:goals_web/widgets/gg_icon_button.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerWidget, WidgetRef;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:uuid/uuid.dart';

class GoalSummary extends ConsumerWidget {
  final GoalPath path;
  final Map<String, Goal> goalMap;
  const GoalSummary({super.key, required this.path, required this.goalMap});

  Goal get goal => goalMap[path.goalId]!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalSummary = hasSummary(goal);
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;
    final comparator = getPriorityComparator(worldContext);

    final colChildren = <Widget>[];

    if (goalSummary != null) {
      colChildren.add(Padding(
        padding: EdgeInsets.only(bottom: uiUnit(2)),
        child: NoteCard(
          path: this.path,
          textEntry: goalSummary,
          onRefresh: () => {},
          isChildGoal: false,
          showTime: false,
          goalMap: this.goalMap,
        ),
      ));
    }

    final indent = uiUnit(4);
    for (final childGoal in goal.subGoalIds
        .map((id) => goalMap[id])
        .whereType<Goal>()
        .sorted(comparator)) {
      final childSummary = hasSummary(childGoal);
      final parentContextComment = hasParentContext(childGoal, goal.id);
      colChildren.add(
        Padding(
            padding: EdgeInsets.only(left: indent),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Breadcrumb(
                  path: this.path,
                  style: Theme.of(context).textTheme.headlineSmall,
                  goalMap: this.goalMap,
                ),
                if (parentContextComment == null)
                  GlassGoalsIconButton(
                    icon: Icons.add,
                    onPressed: () {
                      AppContext.of(context).syncClient.modifyGoal(GoalDelta(
                          id: childGoal.id,
                          logEntry: ParentContextCommentEntry(
                            id: Uuid().v4(),
                            creationTime: DateTime.now(),
                            parentId: this.goal.id,
                            text: DEFAULT_CONTEXT_COMMENT_TEXT,
                          )));
                    },
                  )
              ],
            )),
      );
      if (childSummary != null) {
        colChildren.add(Padding(
          padding: EdgeInsets.only(left: indent),
          child: NoteCard(
            path: this.path,
            goalMap: this.goalMap,
            textEntry: childSummary,
            onRefresh: () => {},
            isChildGoal: true,
            showTime: false,
          ),
        ));
      }

      if (parentContextComment != null) {
        if (childSummary != null) {
          colChildren.add(Padding(
              padding: EdgeInsets.only(left: indent),
              child: Container(
                color: darkElementColor,
                height: 2,
              )));
        }

        colChildren.add(Padding(
          padding: EdgeInsets.only(left: indent),
          child: NoteCard(
            path: this.path,
            goalMap: this.goalMap,
            textEntry: parentContextComment,
            onRefresh: () => {},
            isChildGoal: false,
            showTime: false,
          ),
        ));
      }

      colChildren.add(SizedBox(height: uiUnit(2)));
    }

    final parentContextComments = getAllParentContext(goal);

    for (final parentContextComment in parentContextComments.entries) {
      final parentGoal = goalMap[parentContextComment.key];

      if (parentGoal == null) {
        continue;
      }

      colChildren.add(Padding(
          padding: EdgeInsets.only(left: indent),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Breadcrumb(
                  path: GoalPath([...this.path, parentGoal.id]),
                  goalMap: this.goalMap,
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          )));
      colChildren.add(Padding(
        padding: EdgeInsets.only(left: indent),
        child: NoteCard(
          path: path,
          goalMap: goalMap,
          textEntry: parentContextComment.value,
          onRefresh: () => {},
          isChildGoal: true,
          showTime: false,
        ),
      ));
      colChildren.add(SizedBox(height: uiUnit(2)));
    }

    return Column(
      children: colChildren,
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }
}
