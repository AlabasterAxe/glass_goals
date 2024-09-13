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
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
import '../styles.dart';
import 'goal_actions_context.dart';
import 'goal_item.dart';
import 'goal_separator.dart';
import 'goal_viewer_constants.dart';
import 'providers.dart';
import 'package:collection/collection.dart';

typedef FlattenedGoalItem = ({
  List<String> goalPath,
  bool hasRenderableChildren,
  Map<String, Goal> goalMap,
  List<String> rootPath,
});

typedef FlattenedGoalTreeSection = ({
  String section,
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
  const FlattenedGoalTree({
    super.key,
    this.depthLimit,
    this.showParentName = false,
    required this.hoverActionsBuilder,
    this.showAddGoal = true,
    required this.sections,
  });

  @override
  ConsumerState<FlattenedGoalTree> createState() =>
      _StatefulFlattenedGoalTreeState();
}

class _StatefulFlattenedGoalTreeState extends ConsumerState<FlattenedGoalTree> {
  var _flattenedGoalItems = <FlattenedGoalItem>[];

  List<FlattenedGoalItem> _getFlattenedGoalItemSection(
      WorldContext context,
      Set<String> expandedGoalIds,
      List<String>? textFocus,
      FlattenedGoalTreeSection section) {
    final priorityComparator = getPriorityComparator(context);
    final List<FlattenedGoalItem> flattenedGoals = [];
    for (final Goal goal in section.rootGoalIds
        .map((id) => section.goalMap[id])
        .where((goal) => goal != null)
        .cast<Goal>()
        .sorted(priorityComparator)) {
      traverseDown(
        section.goalMap,
        goal.id,
        onVisit: (goalId, path) {
          flattenedGoals.add((
            goalPath: [section.section, ...section.path, ...path, goalId],
            hasRenderableChildren: section.goalMap[goalId]!.subGoalIds
                .where((gId) => section.goalMap.containsKey(gId))
                .isNotEmpty,
            goalMap: section.goalMap,
            rootPath: [section.section, ...section.path],
          ));

          if (!expandedGoalIds.contains(goalId)) {
            return TraversalDecision.dontRecurse;
          }
        },
        onDepart: (String goalId, List<String> path) {
          final addGoalPath = [
            section.section,
            ...section.path,
            ...path,
            goalId,
            NEW_GOAL_PLACEHOLDER
          ];
          if (this.widget.showAddGoal && pathsMatch(addGoalPath, textFocus)) {
            flattenedGoals.add((
              goalPath: addGoalPath,
              hasRenderableChildren: false,
              goalMap: section.goalMap,
              rootPath: [section.section, ...section.path],
            ));
          }
        },
        childTraversalComparator: priorityComparator,
      );
    }
    if (this.widget.showAddGoal) {
      flattenedGoals.add((
        goalPath: [section.section, ...section.path, NEW_GOAL_PLACEHOLDER],
        hasRenderableChildren: false,
        goalMap: section.goalMap,
        rootPath: [section.section, ...section.path],
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
    final flattenedGoalItems = <FlattenedGoalItem>[];
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

    for (int i = 0; i < _flattenedGoalItems.length; i++) {
      final prevGoal = i > 0 ? _flattenedGoalItems[i - 1] : null;
      final flattenedGoal = _flattenedGoalItems[i];
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
    }
    return Column(children: goalItems);
  }
}
