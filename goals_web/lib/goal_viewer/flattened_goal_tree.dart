import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show Actions, BuildContext, CallbackAction, Column, Widget;
import 'package:goals_core/model.dart'
    show Goal, TraversalDecision, getPriorityComparator, traverseDown;
import 'package:goals_web/goal_viewer/add_subgoal_item.dart';
import 'package:goals_web/goal_viewer/hover_actions.dart'
    show HoverActionsBuilder;
import 'package:goals_web/intents.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;
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

class FlattenedGoalTree extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<FlattenedGoalTree> createState() => _FlattenedGoalTreeState();
}

class _FlattenedGoalTreeState extends ConsumerState<FlattenedGoalTree> {
  List<FlattenedGoalItem> _flattenedGoalItems = [];

  @override
  void initState() {
    super.initState();
    _updateFlattenedGoalItems();
  }

  void _updateFlattenedGoalItems() {
    final context =
        ref.read(worldContextProvider).value ?? worldContextStream.value;
    final expandedGoalPaths =
        ref.read(expandedGoalsProvider).value ?? expandedGoalsStream.value;
    final textFocus =
        ref.read(textFocusProvider).value ?? textFocusStream.value;
    final priorityComparator = getPriorityComparator(context);
    final List<FlattenedGoalItem> flattenedGoals = [];
    for (final Goal goal in this
        .widget
        .rootGoalIds
        .map((id) => this.widget.goalMap[id])
        .where((goal) => goal != null)
        .cast<Goal>()
        .sorted(priorityComparator)) {
      traverseDown(
        this.widget.goalMap,
        goal.id,
        onVisit: (goalId, path) {
          final fullGoalPath = [
            this.widget.section,
            ...this.widget.path,
            ...path,
            goalId
          ];
          flattenedGoals.add((
            goalPath: fullGoalPath,
            hasRenderableChildren: this
                .widget
                .goalMap[goalId]!
                .subGoalIds
                .where((gId) => this.widget.goalMap.containsKey(gId))
                .isNotEmpty,
          ));

          if (expandedGoalPaths
                  .firstWhereOrNull((p) => pathsMatch(p, fullGoalPath)) ==
              null) {
            return TraversalDecision.dontRecurse;
          }
        },
        onDepart: (String goalId, List<String> path) {
          final addGoalPath = [
            this.widget.section,
            ...this.widget.path,
            ...path,
            goalId,
            NEW_GOAL_PLACEHOLDER
          ];
          if (this.widget.showAddGoal && pathsMatch(addGoalPath, textFocus)) {
            flattenedGoals.add((
              goalPath: addGoalPath,
              hasRenderableChildren: false,
            ));
          }
        },
        childTraversalComparator: priorityComparator,
      );
    }
    if (this.widget.showAddGoal) {
      flattenedGoals.add((
        goalPath: [
          this.widget.section,
          ...this.widget.path,
          NEW_GOAL_PLACEHOLDER
        ],
        hasRenderableChildren: false,
      ));
    }
    setState(() {
      _flattenedGoalItems = flattenedGoals;
    });
  }

  @override
  void didUpdateWidget(FlattenedGoalTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalMap != this.widget.goalMap ||
        oldWidget.rootGoalIds != this.widget.rootGoalIds ||
        oldWidget.path != this.widget.path) {
      _updateFlattenedGoalItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(expandedGoalsProvider, (_, __) => _updateFlattenedGoalItems());
    ref.listen(worldContextProvider, (_, __) => _updateFlattenedGoalItems());
    ref.listen(textFocusProvider, (_, __) => _updateFlattenedGoalItems());

    final hasMouse = ref.watch(hasMouseProvider);

    final goalItems = <Widget>[];
    final onDropGoal = GoalActionsContext.of(context).onDropGoal;

    for (int i = 0; i < this._flattenedGoalItems.length; i++) {
      final prevGoal = i > 0 ? this._flattenedGoalItems[i - 1] : null;
      final flattenedGoal = this._flattenedGoalItems[i];
      final goalId = flattenedGoal.goalPath.last;
      goalItems.add(GoalSeparator(
          isFirst: i == 0,
          prevGoalPath:
              prevGoal?.goalPath ?? [widget.section, ...this.widget.path],
          nextGoalPath: flattenedGoal.goalPath,
          path: this.widget.path,
          goalMap: this.widget.goalMap,
          onDropGoal: (goalDragDetails) {
            onDropGoal(goalDragDetails.goalId,
                sourcePath: goalDragDetails.sourcePath,
                prevDropPath:
                    prevGoal?.goalPath ?? [widget.section, ...this.widget.path],
                nextDropPath: flattenedGoal.goalPath);
          }));
      goalItems.add(goalId != NEW_GOAL_PLACEHOLDER
          ? GoalItemWidget(
              onDropGoal: (details) {
                onDropGoal(
                  details.goalId,
                  sourcePath: details.sourcePath,
                  dropPath: flattenedGoal.goalPath,
                );
              },
              padding: EdgeInsets.only(
                  left: uiUnit(4) *
                      (flattenedGoal.goalPath.length -
                          (2 + this.widget.path.length))),
              goal: this.widget.goalMap[goalId]!,
              hoverActionsBuilder: this.widget.hoverActionsBuilder,
              hasRenderableChildren: flattenedGoal.hasRenderableChildren,
              showExpansionArrow:
                  flattenedGoal.hasRenderableChildren || widget.showAddGoal,
              dragHandle: !hasMouse
                  ? GoalItemDragHandle.bullet
                  : GoalItemDragHandle.item,
              path: flattenedGoal.goalPath,
            )
          : AddSubgoalItemWidget(
              path: flattenedGoal.goalPath,
            ));
    }
    return Actions(actions: {
      NextIntent: CallbackAction(
        onInvoke: (_) {
          final hoveredIndex = _flattenedGoalItems.indexWhere(
              (item) => pathsMatch(item.goalPath, hoverEventStream.value));
          if (hoveredIndex != -1 &&
              hoveredIndex < _flattenedGoalItems.length - 1) {
            hoverEventStream
                .add(_flattenedGoalItems[hoveredIndex + 1].goalPath);
          }
        },
      ),
      PreviousIntent: CallbackAction(
        onInvoke: (_) {
          final hoveredIndex = _flattenedGoalItems.indexWhere(
              (item) => pathsMatch(item.goalPath, hoverEventStream.value));
          if (hoveredIndex != -1 && hoveredIndex > 0) {
            hoverEventStream
                .add(_flattenedGoalItems[hoveredIndex - 1].goalPath);
          }
        },
      ),
    }, child: Column(children: goalItems));
  }
}
