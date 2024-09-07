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
    show ConsumerWidget, WidgetRef;
import '../styles.dart';
import 'goal_actions_context.dart';
import 'goal_item.dart';
import 'goal_separator.dart';
import 'goal_viewer_constants.dart';
import 'providers.dart';
import 'package:collection/collection.dart' show IterableExtension;

typedef FlattenedGoalItem = ({
  List<String> goalPath,
  bool hasRenderableChildren,
});

class FlattenedGoalTree extends ConsumerWidget {
  final Map<String, Goal> goalMap;
  final List<String> rootGoalIds;
  final int? depthLimit;
  final bool showParentName;
  final HoverActionsBuilder hoverActionsBuilder;
  final List<String> path;
  final String section;
  final bool showAddGoal;
  const FlattenedGoalTree({
    super.key,
    required this.goalMap,
    required this.rootGoalIds,
    this.depthLimit,
    this.showParentName = false,
    required this.hoverActionsBuilder,
    this.showAddGoal = true,
    this.path = const [],
    required this.section,
  });

  List<FlattenedGoalItem> _getFlattenedGoalItems(WorldContext context,
      Set<String> expandedGoalIds, List<String>? textFocus) {
    final priorityComparator = getPriorityComparator(context);
    final List<FlattenedGoalItem> flattenedGoals = [];
    for (final Goal goal in this
        .rootGoalIds
        .map((id) => this.goalMap[id])
        .where((goal) => goal != null)
        .cast<Goal>()
        .sorted(priorityComparator)) {
      traverseDown(
        this.goalMap,
        goal.id,
        onVisit: (goalId, path) {
          print([this.section, ...this.path, ...path, goalId]);
          flattenedGoals.add((
            goalPath: [this.section, ...this.path, ...path, goalId],
            hasRenderableChildren: this
                .goalMap[goalId]!
                .subGoals
                .where((g) => this.goalMap.containsKey(g.id))
                .isNotEmpty,
          ));

          if (!expandedGoalIds.contains(goalId)) {
            return TraversalDecision.dontRecurse;
          }
        },
        onDepart: (String goalId, List<String> path) {
          final addGoalPath = [
            this.section,
            ...this.path,
            ...path,
            goalId,
            NEW_GOAL_PLACEHOLDER
          ];
          print("add goal path $addGoalPath");
          print("text focus: $textFocus");
          if (this.showAddGoal && pathsMatch(addGoalPath, textFocus)) {
            print('matches!');
            flattenedGoals.add((
              goalPath: addGoalPath,
              hasRenderableChildren: false,
            ));
          }
        },
        childTraversalComparator: priorityComparator,
      );
    }
    if (this.showAddGoal) {
      flattenedGoals.add((
        goalPath: [this.section, ...this.path, NEW_GOAL_PLACEHOLDER],
        hasRenderableChildren: false,
      ));
    }
    return flattenedGoals;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedGoalIds =
        ref.watch(expandedGoalsProvider).value ?? expandedGoalsStream.value;
    final worldContext =
        ref.watch(worldContextProvider).value ?? worldContextStream.value;
    final textFocus =
        ref.watch(textFocusProvider).value ?? textFocusStream.value;
    final flattenedGoalItems =
        _getFlattenedGoalItems(worldContext, expandedGoalIds, textFocus);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    final goalItems = <Widget>[];
    final onDropGoal = GoalActionsContext.of(context).onDropGoal;

    for (int i = 0; i < flattenedGoalItems.length; i++) {
      final prevGoal = i > 0 ? flattenedGoalItems[i - 1] : null;
      final flattenedGoal = flattenedGoalItems[i];
      final goalId = flattenedGoal.goalPath.last;
      goalItems.add(GoalSeparator(
          isFirst: i == 0,
          prevGoalPath: prevGoal?.goalPath ?? [section, ...this.path],
          nextGoalPath: flattenedGoal.goalPath,
          goalMap: this.goalMap,
          onDropGoal: (droppedGoalId) {
            onDropGoal(droppedGoalId,
                prevDropPath: prevGoal?.goalPath ?? [section, ...this.path],
                nextDropPath: flattenedGoal.goalPath);
          }));
      goalItems.add(Padding(
        padding: EdgeInsets.only(
            left: uiUnit(4) *
                (flattenedGoal.goalPath.length - (2 + this.path.length))),
        child: goalId != NEW_GOAL_PLACEHOLDER
            ? GoalItemWidget(
                onDropGoal: (droppedGoalId) {
                  onDropGoal(
                    droppedGoalId,
                    dropPath: flattenedGoal.goalPath,
                  );
                },
                goal: this.goalMap[goalId]!,
                hoverActionsBuilder: this.hoverActionsBuilder,
                hasRenderableChildren: flattenedGoal.hasRenderableChildren,
                showExpansionArrow:
                    flattenedGoal.hasRenderableChildren || showAddGoal,
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
