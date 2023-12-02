import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show BuildContext, Column, DragTarget, MediaQuery, Widget;
import 'package:goals_core/model.dart'
    show
        Goal,
        TraversalDecision,
        WorldContext,
        getPriorityComparator,
        traverseDown;
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/add_subgoal_item.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart'
    show HoverActionsBuilder;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerWidget, WidgetRef;
import 'package:uuid/uuid.dart';

import '../app_context.dart';
import '../styles.dart';
import 'goal_item.dart';
import 'goal_separator.dart';
import 'providers.dart';
import 'package:collection/collection.dart' show IterableExtension;

typedef FlattenedGoalItem = ({
  List<String> goalPath,
  bool hasRenderableChildren,
});

const String NEW_GOAL_PLACEHOLDER = "[NEW_GOAL]";

class FlattenedGoalTree extends ConsumerWidget {
  final Map<String, Goal> goalMap;
  final List<String> rootGoalIds;
  final Function(String goalId) onSelected;
  final Function(String goalId)? onFocused;
  final Function(String goalId, {bool? expanded}) onExpanded;
  final Function(String?, String)? onAddGoal;
  final int? depthLimit;
  final bool showParentName;
  final HoverActionsBuilder hoverActionsBuilder;
  final List<String> path;
  const FlattenedGoalTree({
    super.key,
    required this.goalMap,
    required this.rootGoalIds,
    required this.onSelected,
    required this.onExpanded,
    this.onFocused,
    this.depthLimit,
    this.showParentName = false,
    required this.hoverActionsBuilder,
    this.onAddGoal,
    this.path = const [],
  });

  List<FlattenedGoalItem> _getFlattenedGoalItems(
      WorldContext context, Set<String> expandedGoalIds) {
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
          flattenedGoals.add((
            goalPath: [...this.path, ...path, goalId],
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
          if (expandedGoalIds.contains(goalId) && this.onAddGoal != null) {
            flattenedGoals.add((
              goalPath: [...this.path, ...path, goalId, NEW_GOAL_PLACEHOLDER],
              hasRenderableChildren: false,
            ));
          }
        },
        childTraversalComparator: priorityComparator,
      );
    }
    if (this.onAddGoal != null) {
      flattenedGoals.add((
        goalPath: [...this.path, NEW_GOAL_PLACEHOLDER],
        hasRenderableChildren: false,
      ));
    }
    return flattenedGoals;
  }

  _moveGoals(BuildContext context, String newParentId, Set<String> goalIds) {
    final List<GoalDelta> goalDeltas = [];
    for (final goalId in goalIds) {
      goalDeltas.add(GoalDelta(
          id: goalId,
          logEntry: SetParentLogEntry(
              id: Uuid().v4(),
              parentId: newParentId,
              creationTime: DateTime.now())));
    }
    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedGoalIds = ref.watch(expandedGoalsProvider);
    final worldContext = ref.watch(worldContextProvider);
    final flattenedGoalItems =
        _getFlattenedGoalItems(worldContext, expandedGoalIds);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    final goalItems = <Widget>[];
    for (int i = 0; i < flattenedGoalItems.length; i++) {
      final previousGoal = i > 0 ? flattenedGoalItems[i - 1] : null;
      final flattenedGoal = flattenedGoalItems[i];
      final goalId = flattenedGoal.goalPath.last;
      goalItems.add(GoalSeparator(
        goalMap: this.goalMap,
        previousGoalPath: previousGoal?.goalPath ?? this.path,
        nextGoalPath: flattenedGoal.goalPath,
      ));
      goalItems.add(Padding(
        padding: EdgeInsets.only(
            left: uiUnit(4) * (flattenedGoal.goalPath.length - 1)),
        child: goalId != NEW_GOAL_PLACEHOLDER
            ? GoalItemWidget(
                onDropGoal: (droppedGoalId) {
                  final selectedGoals = ref.read(selectedGoalsProvider);
                  final selectedAndDraggedGoals = {
                    ...ref.read(selectedGoalsProvider),
                    droppedGoalId
                  };
                  this._moveGoals(
                      context,
                      goalId,
                      selectedGoals.contains(droppedGoalId)
                          ? selectedAndDraggedGoals
                          : {droppedGoalId});
                  ref.read(selectedGoalsProvider.notifier).clear();
                },
                goal: this.goalMap[goalId]!,
                onExpanded: this.onExpanded,
                onFocused: this.onFocused,
                hoverActionsBuilder: this.hoverActionsBuilder,
                hasRenderableChildren: flattenedGoal.hasRenderableChildren,
                showExpansionArrow: true,
                dragHandle: isNarrow
                    ? GoalItemDragHandle.bullet
                    : GoalItemDragHandle.item,
              )
            : AddSubgoalItemWidget(
                onAddGoal: this.onAddGoal!,
                path: flattenedGoal.goalPath,
              ),
      ));
    }
    return Column(children: goalItems);
  }
}
