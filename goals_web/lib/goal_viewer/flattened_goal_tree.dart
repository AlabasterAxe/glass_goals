import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show BuildContext, Column, Container, DragTarget, MediaQuery, Widget;
import 'package:goals_core/model.dart'
    show Goal, TraversalDecision, WorldContext, getGoalPriority, traverseDown;
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

typedef FlattenedGoalItem = ({
  int depth,
  String? goalId,
  bool hasRenderableChildren,
  String? parentId,
});

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
    required this.onAddGoal,
  });

  List<FlattenedGoalItem> _getFlattenedGoalItems(
      WorldContext context, Set<String> expandedGoalIds) {
    final List<FlattenedGoalItem> flattenedGoals = [];
    for (final goalId in this.rootGoalIds) {
      traverseDown(
        this.goalMap,
        goalId,
        onVisit: (goalId, path) {
          flattenedGoals.add((
            depth: path.length,
            parentId: path.isNotEmpty ? path.last : null,
            goalId: goalId,
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
          if (expandedGoalIds.contains(goalId)) {
            flattenedGoals.add((
              depth: path.length + 1,
              goalId: null,
              hasRenderableChildren: false,
              parentId: goalId,
            ));
          }
        },
        childTraversalComparator: (goalA, goalB) {
          return getGoalPriority(context, goalA)
              .compareTo(getGoalPriority(context, goalB));
        },
      );
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
      if (flattenedGoal.goalId != null || this.onAddGoal != null) {
        goalItems.add(GoalSeparator(
          goalMap: this.goalMap,
          previousGoalId: previousGoal?.goalId,
          nextGoalId: flattenedGoal.goalId,
        ));
        goalItems.add(Padding(
          padding: EdgeInsets.only(left: uiUnit(4) * flattenedGoal.depth),
          child: flattenedGoal.goalId != null
              ? DragTarget<String>(
                  onAccept: (droppedGoalId) {
                    final selectedGoals = ref.read(selectedGoalsProvider);
                    final selectedAndDraggedGoals = {
                      ...ref.read(selectedGoalsProvider),
                      droppedGoalId
                    };
                    this._moveGoals(
                        context,
                        flattenedGoal.goalId!,
                        selectedGoals.contains(droppedGoalId)
                            ? selectedAndDraggedGoals
                            : {droppedGoalId});
                    ref.read(selectedGoalsProvider.notifier).clear();
                  },
                  builder: (context, _, __) => GoalItemWidget(
                    goal: this.goalMap[flattenedGoal.goalId!]!,
                    onExpanded: this.onExpanded,
                    onFocused: this.onFocused,
                    hovered: false,
                    hoverActionsBuilder: this.hoverActionsBuilder,
                    hasRenderableChildren: flattenedGoal.hasRenderableChildren,
                    showExpansionArrow: true,
                    dragHandle: isNarrow
                        ? GoalItemDragHandle.bullet
                        : GoalItemDragHandle.item,
                    onDragEnd: null,
                    onDragStarted: null,
                  ),
                )
              : AddSubgoalItemWidget(
                  onAddGoal: this.onAddGoal!,
                  parentId: flattenedGoal.parentId!),
        ));
      }
    }
    if (flattenedGoalItems.isNotEmpty) {
      goalItems.add(GoalSeparator(
        goalMap: this.goalMap,
        previousGoalId: flattenedGoalItems.last.goalId,
        nextGoalId: null,
      ));
    }

    if (this.onAddGoal != null) {
      goalItems.add(AddSubgoalItemWidget(onAddGoal: this.onAddGoal!));
    }
    return Column(children: goalItems);
  }
}
