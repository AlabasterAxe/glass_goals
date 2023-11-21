import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show BuildContext, Column, Container, Widget;
import 'package:goals_core/model.dart'
    show Goal, TraversalDecision, traverseDown;
import 'package:goals_web/goal_viewer/add_subgoal_item.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart'
    show HoverActionsBuilder;
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerWidget, WidgetRef;

import '../styles.dart';
import 'goal_item.dart';
import 'providers.dart';

typedef FlattenedGoalItem = ({
  int depth,
  String? goalId,
  bool hasRenderableChildren,
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

  List<FlattenedGoalItem> _getFlattenedGoalItems(Set<String> expandedGoalIds) {
    final List<FlattenedGoalItem> flattenedGoals = [];
    for (final goalId in this.rootGoalIds) {
      int? prevDepth;
      traverseDown(this.goalMap, goalId, (goalId, path) {
        if (prevDepth != null && prevDepth! > path.length) {
          flattenedGoals.add((
            depth: path.length,
            goalId: null,
            hasRenderableChildren: false,
          ));
        }
        prevDepth = path.length;
        flattenedGoals.add((
          depth: path.length,
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
      });
    }
    return flattenedGoals;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedGoalIds = ref.watch(expandedGoalsProvider);
    final flattenedGoalItems = _getFlattenedGoalItems(expandedGoalIds);
    return Column(children: [
      for (final flattenedGoal in flattenedGoalItems)
        flattenedGoal.goalId != null
            ? Padding(
                padding: EdgeInsets.only(left: uiUnit(3) * flattenedGoal.depth),
                child: GoalItemWidget(
                  goal: this.goalMap[flattenedGoal.goalId!]!,
                  onExpanded: this.onExpanded,
                  onFocused: this.onFocused,
                  hovered: false,
                  hoverActionsBuilder: this.hoverActionsBuilder,
                  hasRenderableChildren: flattenedGoal.hasRenderableChildren,
                  showExpansionArrow: true,
                  dragHandle: GoalItemDragHandle.none,
                  onDragEnd: null,
                  onDragStarted: null,
                ),
              )
            : AddSubgoalItemWidget(onAddGoal: this.onAddGoal!),
      this.onAddGoal != null
          ? AddSubgoalItemWidget(onAddGoal: this.onAddGoal!)
          : Container(),
    ]);
  }
}
