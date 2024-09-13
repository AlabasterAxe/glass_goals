import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show BuildContext, Column, MediaQuery, Widget;
import 'package:goals_core/model.dart'
    show
        Goal,
        TraversalDecision,
        WorldContext,
        getPriorityComparator,
        traverseDown;
import 'package:goals_web/goal_viewer/add_subgoal_item.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart'
    show HoverActionsBuilder;
import 'package:goals_web/widgets/gg_icon_button.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import '../styles.dart';
import 'goal_actions_context.dart';
import 'goal_item.dart';
import 'goal_separator.dart';
import 'goal_viewer_constants.dart';
import 'providers.dart';
import 'package:collection/collection.dart';

sealed class _FlattenedTreeItem {
  const _FlattenedTreeItem();
}

class _GoalItem extends _FlattenedTreeItem {
  final List<String> goalPath;
  final bool hasRenderableChildren;
  final Map<String, Goal> goalMap;
  final List<String> rootPath;

  const _GoalItem({
    required this.goalPath,
    required this.hasRenderableChildren,
    required this.goalMap,
    required this.rootPath,
  });
}

class _SectionTitle extends _FlattenedTreeItem {
  final String title;
  final String key;
  final bool expanded;

  const _SectionTitle(this.title, this.key, this.expanded);
}

typedef FlattenedGoalItem = ({
  List<String> goalPath,
  bool hasRenderableChildren,
  Map<String, Goal> goalMap,
  List<String> rootPath,
});

typedef FlattenedGoalTreeSection = ({
  String key,
  String? title,
  Map<String, Goal> goalMap,
  List<String> rootGoalIds,
  bool expanded,
  List<String> path,
});

class FlattenedGoalTree extends ConsumerStatefulWidget {
  final int? depthLimit;
  final bool showParentName;
  final HoverActionsBuilder hoverActionsBuilder;
  final List<FlattenedGoalTreeSection> sections;
  final bool showAddGoal;
  final Function(String)? toggleSectionExpansion;
  const FlattenedGoalTree({
    super.key,
    this.depthLimit,
    this.showParentName = false,
    required this.hoverActionsBuilder,
    this.showAddGoal = true,
    required this.sections,
    this.toggleSectionExpansion,
  });

  @override
  ConsumerState<FlattenedGoalTree> createState() =>
      _StatefulFlattenedGoalTreeState();
}

class _StatefulFlattenedGoalTreeState extends ConsumerState<FlattenedGoalTree> {
  var _flattenedGoalItems = <_FlattenedTreeItem>[];

  List<_FlattenedTreeItem> _getFlattenedGoalItemSection(
      WorldContext context,
      Set<String> expandedGoalIds,
      List<String>? textFocus,
      FlattenedGoalTreeSection section) {
    final priorityComparator = getPriorityComparator(context);
    final List<_FlattenedTreeItem> flattenedGoals = [];
    if (section.title != null) {
      flattenedGoals
          .add(_SectionTitle(section.title!, section.key, section.expanded));
    }
    if (!section.expanded) {
      return flattenedGoals;
    }
    for (final Goal goal in section.rootGoalIds
        .map((id) => section.goalMap[id])
        .where((goal) => goal != null)
        .cast<Goal>()
        .sorted(priorityComparator)) {
      traverseDown(
        section.goalMap,
        goal.id,
        onVisit: (goalId, path) {
          flattenedGoals.add(_GoalItem(
            goalPath: [section.key, ...section.path, ...path, goalId],
            hasRenderableChildren: section.goalMap[goalId]!.subGoalIds
                .where((gId) => section.goalMap.containsKey(gId))
                .isNotEmpty,
            goalMap: section.goalMap,
            rootPath: [section.key, ...section.path],
          ));

          if (!expandedGoalIds.contains(goalId)) {
            return TraversalDecision.dontRecurse;
          }
        },
        onDepart: (String goalId, List<String> path) {
          final addGoalPath = [
            section.key,
            ...section.path,
            ...path,
            goalId,
            NEW_GOAL_PLACEHOLDER
          ];
          if (this.widget.showAddGoal && pathsMatch(addGoalPath, textFocus)) {
            flattenedGoals.add(_GoalItem(
              goalPath: addGoalPath,
              hasRenderableChildren: false,
              goalMap: section.goalMap,
              rootPath: [section.key, ...section.path],
            ));
          }
        },
        childTraversalComparator: priorityComparator,
      );
    }
    if (this.widget.showAddGoal) {
      flattenedGoals.add(_GoalItem(
        goalPath: [section.key, ...section.path, NEW_GOAL_PLACEHOLDER],
        hasRenderableChildren: false,
        goalMap: section.goalMap,
        rootPath: [section.key, ...section.path],
      ));
    }
    return flattenedGoals;
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.sections != oldWidget.sections) {
      _rebuildFlattenedGoalItems(
        sections: widget.sections,
        worldContext: worldContextStream.value,
        expandedGoalIds: expandedGoalsStream.value,
        textFocus: textFocusStream.value,
      );
    }
  }

  _rebuildFlattenedGoalItems({
    required List<FlattenedGoalTreeSection> sections,
    required WorldContext worldContext,
    required Set<String> expandedGoalIds,
    required List<String>? textFocus,
  }) {
    final flattenedGoalItems = <_FlattenedTreeItem>[];
    for (final section in sections) {
      flattenedGoalItems.addAll(_getFlattenedGoalItemSection(
        worldContext,
        expandedGoalIds,
        textFocus,
        section,
      ));
    }

    setState(() {
      _flattenedGoalItems = flattenedGoalItems;
    });
  }

  @override
  void initState() {
    super.initState();
    _rebuildFlattenedGoalItems(
      expandedGoalIds: expandedGoalsStream.value,
      worldContext: worldContextStream.value,
      textFocus: textFocusStream.value,
      sections: this.widget.sections,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(expandedGoalsProvider, (_, expandedGoalIds) {
      _rebuildFlattenedGoalItems(
        expandedGoalIds: expandedGoalIds.value ?? expandedGoalsStream.value,
        worldContext: worldContextStream.value,
        textFocus: textFocusStream.value,
        sections: this.widget.sections,
      );
    });
    ref.listen(worldContextProvider, (_, worldContext) {
      _rebuildFlattenedGoalItems(
        expandedGoalIds: expandedGoalsStream.value,
        worldContext: worldContext.value ?? worldContextStream.value,
        textFocus: textFocusStream.value,
        sections: this.widget.sections,
      );
    });

    ref.listen(textFocusProvider, (_, textFocus) {
      _rebuildFlattenedGoalItems(
        expandedGoalIds: expandedGoalsStream.value,
        worldContext: worldContextStream.value,
        textFocus: textFocus.value,
        sections: this.widget.sections,
      );
    });
    final isNarrow = MediaQuery.of(context).size.width < 600;

    final goalItems = <Widget>[];
    final onDropGoal = GoalActionsContext.of(context).onDropGoal;

    _GoalItem? prevGoal;
    for (int i = 0; i < _flattenedGoalItems.length; i++) {
      final flattenedGoal = _flattenedGoalItems[i];

      if (flattenedGoal is _SectionTitle) {
        goalItems.add(Row(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: uiUnit())
                  .copyWith(left: uiUnit(2)),
              child: Text(
                flattenedGoal.title,
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            GlassGoalsIconButton(
              icon: flattenedGoal.expanded
                  ? Icons.arrow_drop_down
                  : Icons.arrow_right,
              onPressed: () {
                this.widget.toggleSectionExpansion?.call(flattenedGoal.key);
              },
            ),
          ],
        ));
        prevGoal = null;
        continue;
      } else if (flattenedGoal is _GoalItem) {
        final goalId = flattenedGoal.goalPath.last;

        goalItems.add(GoalSeparator(
            isFirst: i == 0,
            prevGoalPath: prevGoal?.goalPath ?? flattenedGoal.rootPath,
            nextGoalPath: flattenedGoal.goalPath,
            goalMap: flattenedGoal.goalMap,
            onDropGoal: (goalDragDetails) {
              onDropGoal(goalDragDetails.goalId,
                  sourcePath: goalDragDetails.sourcePath,
                  prevDropPath: prevGoal?.goalPath ?? flattenedGoal.rootPath,
                  nextDropPath: flattenedGoal.goalPath);
            }));
        goalItems.add(Padding(
          padding: EdgeInsets.only(
              left: uiUnit(4) *
                  (flattenedGoal.goalPath.length -
                      (1 + flattenedGoal.rootPath.length))),
          child: goalId != NEW_GOAL_PLACEHOLDER
              ? GoalItemWidget(
                  onDropGoal: (details) {
                    onDropGoal(
                      details.goalId,
                      sourcePath: details.sourcePath,
                      dropPath: flattenedGoal.goalPath,
                    );
                  },
                  goal: flattenedGoal.goalMap[goalId]!,
                  hoverActionsBuilder: this.widget.hoverActionsBuilder,
                  hasRenderableChildren: flattenedGoal.hasRenderableChildren,
                  showExpansionArrow: flattenedGoal.hasRenderableChildren ||
                      this.widget.showAddGoal,
                  dragHandle: isNarrow
                      ? GoalItemDragHandle.bullet
                      : GoalItemDragHandle.item,
                  path: flattenedGoal.goalPath,
                )
              : AddSubgoalItemWidget(
                  path: flattenedGoal.goalPath,
                ),
        ));
        prevGoal = flattenedGoal;
      }
    }
    return Column(children: goalItems);
  }
}
