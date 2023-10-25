import 'package:flutter/rendering.dart' show CrossAxisAlignment;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Column,
        Container,
        DragTarget,
        Expanded,
        MediaQuery,
        Row,
        SizedBox,
        Widget;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/add_subgoal_item.dart';
import 'package:goals_web/goal_viewer/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../app_context.dart';
import '../styles.dart' show uiUnit;
import 'goal_item.dart' show GoalItemDragHandle, GoalItemWidget;

class GoalTreeWidget extends StatefulHookConsumerWidget {
  final Map<String, Goal> goalMap;
  final String rootGoalId;
  final Function(String goalId) onSelected;
  final Function(String goalId)? onFocused;
  final Function(String goalId, {bool expanded}) onExpanded;
  final Function(String?, String)? onAddGoal;
  final int? depthLimit;
  final bool showParentName;
  final Widget hoverActions;
  const GoalTreeWidget({
    super.key,
    required this.goalMap,
    required this.rootGoalId,
    required this.onSelected,
    required this.onExpanded,
    this.onFocused,
    this.depthLimit,
    this.showParentName = false,
    required this.hoverActions,
    required this.onAddGoal,
  });

  @override
  ConsumerState<GoalTreeWidget> createState() => _GoalTreeWidgetState();
}

class _GoalTreeWidgetState extends ConsumerState<GoalTreeWidget> {
  bool hovered = false;
  bool dragging = false;

  moveGoals(String newParentId, Set<String> goalIds) {
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
  Widget build(BuildContext context) {
    final Goal rootGoal = widget.goalMap[widget.rootGoalId]!;
    final selectedGoals = ref.watch(selectedGoalsProvider);
    final isExpanded = ref.watch(expandedGoalsProvider).contains(rootGoal.id);
    final isFocused = ref.watch(focusedGoalProvider) == rootGoal.id;
    final hasRenderableChildren = widget.goalMap[widget.rootGoalId]!.subGoals
        .any((element) => widget.goalMap.containsKey(element.id));
    final isNarrow = MediaQuery.of(context).size.width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<String>(
          onAccept: (droppedGoalId) {
            final selectedAndDraggedGoals = {...selectedGoals, droppedGoalId};
            moveGoals(
                rootGoal.id,
                selectedGoals.contains(droppedGoalId)
                    ? selectedAndDraggedGoals
                    : {droppedGoalId});
            ref.read(selectedGoalsProvider.notifier).clear();
          },
          onMove: (_) {
            setState(() {
              hovered = true;
            });
          },
          onLeave: (_) {
            setState(() {
              hovered = false;
            });
          },
          builder: (context, _, __) => GoalItemWidget(
            goal: rootGoal,
            onDragEnd: () {
              setState(() {
                hovered = false;
                dragging = false;
              });
            },
            onDragStarted: () {
              setState(() {
                dragging = true;
              });
            },
            onFocused: widget.onFocused,
            focused: isFocused,
            hovered: hovered && !dragging,
            hoverActions: widget.hoverActions,
            hasRenderableChildren: hasRenderableChildren,
            onExpanded: widget.onExpanded,
            dragHandle:
                isNarrow ? GoalItemDragHandle.bullet : GoalItemDragHandle.item,
          ),
        ),
        isExpanded && (widget.depthLimit == null || widget.depthLimit! > 0)
            ? Row(children: [
                SizedBox(width: uiUnit(5)),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final subGoal in rootGoal.subGoals)
                          widget.goalMap.containsKey(subGoal.id)
                              ? GoalTreeWidget(
                                  goalMap: widget.goalMap,
                                  rootGoalId: subGoal.id,
                                  onSelected: widget.onSelected,
                                  onFocused: widget.onFocused,
                                  onExpanded: widget.onExpanded,
                                  depthLimit: widget.depthLimit == null
                                      ? null
                                      : widget.depthLimit! - 1,
                                  hoverActions: widget.hoverActions,
                                  onAddGoal: widget.onAddGoal,
                                )
                              : null,
                        widget.onAddGoal != null
                            ? AddSubgoalItemWidget(
                                parentId: rootGoal.id,
                                onAddGoal: widget.onAddGoal!,
                              )
                            : Container(),
                      ].where((element) => element != null).toList().cast()),
                )
              ])
            : Container()
      ],
    );
  }
}
