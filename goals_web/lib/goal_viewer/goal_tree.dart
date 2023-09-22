import 'dart:developer';

import 'package:flutter/material.dart' show Colors, Icon, IconButton, Icons;
import 'package:flutter/painting.dart' show TextDecoration, TextStyle;
import 'package:flutter/rendering.dart'
    show BoxDecoration, BoxShape, CrossAxisAlignment, EdgeInsets;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Column,
        Container,
        DragTarget,
        Draggable,
        Padding,
        Row,
        SizedBox,
        State,
        StatefulWidget,
        Text,
        Widget;
import 'package:goals_core/model.dart' show Goal;
import 'package:goals_core/sync.dart';
import 'package:goals_web/goal_viewer/add_subgoal_item.dart';

import '../app_context.dart';
import 'goal_item.dart' show GoalItemWidget;

class GoalTreeWidget extends StatefulWidget {
  final Map<String, Goal> goalMap;
  final String rootGoalId;
  final Set<String> selectedGoals;
  final Set<String> expandedGoals;
  final Function(String goalId) onSelected;
  final Function(String goalId, {bool expanded}) onExpanded;
  final int? depthLimit;
  final bool showParentName;
  const GoalTreeWidget({
    super.key,
    required this.goalMap,
    required this.rootGoalId,
    required this.selectedGoals,
    required this.onSelected,
    required this.expandedGoals,
    required this.onExpanded,
    this.depthLimit,
    this.showParentName = false,
  });

  @override
  State<GoalTreeWidget> createState() => _GoalTreeWidgetState();
}

class _GoalTreeWidgetState extends State<GoalTreeWidget> {
  bool hovered = false;
  bool dragging = false;

  moveGoals(String newParentId, Set<String> goalIds) {
    final List<GoalDelta> goalDeltas = [];
    for (final goalId in goalIds) {
      goalDeltas.add(GoalDelta(id: goalId, parentId: newParentId));
    }
    AppContext.of(context).syncClient.modifyGoals(goalDeltas);
  }

  @override
  Widget build(BuildContext context) {
    final Goal rootGoal = widget.goalMap[widget.rootGoalId]!;
    final isExpanded = widget.expandedGoals.contains(rootGoal.id);
    final isSelected = widget.selectedGoals.contains(rootGoal.id);
    final hasRenderableChildren = widget.goalMap[widget.rootGoalId]!.subGoals
        .any((element) => widget.goalMap.containsKey(element.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<String>(
          onAccept: (droppedGoalId) {
            final selectedAndDraggedGoals = {
              ...widget.selectedGoals,
              droppedGoalId
            };
            moveGoals(rootGoal.id, selectedAndDraggedGoals);
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
          builder: (context, _, __) => Draggable<String>(
            data: rootGoal.id,
            onDragEnd: (_) {
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
            feedback: Container(
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                    (isSelected
                            ? widget.selectedGoals.length
                            : widget.selectedGoals.length + 1)
                        .toString(),
                    style: const TextStyle(
                        fontSize: 20,
                        decoration: TextDecoration.none,
                        color: Colors.white)),
              ),
            ),
            child: Row(
              children: [
                GoalItemWidget(
                  goal: rootGoal,
                  selected: isSelected,
                  onSelected: (value) {
                    widget.onSelected(rootGoal.id);
                  },
                  hovered: hovered && !dragging,
                  parent: widget.showParentName
                      ? widget.goalMap[rootGoal.parentId]
                      : null,
                ),
                IconButton(
                    onPressed: () => widget.onExpanded(rootGoal.id),
                    icon: Icon(isExpanded
                        ? Icons.arrow_drop_down
                        : hasRenderableChildren
                            ? Icons.arrow_right
                            : Icons.add)),
              ],
            ),
          ),
        ),
        isExpanded && (widget.depthLimit == null || widget.depthLimit! > 0)
            ? Row(children: [
                const SizedBox(width: 20),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final subGoal in rootGoal.subGoals)
                        widget.goalMap.containsKey(subGoal.id)
                            ? GoalTreeWidget(
                                goalMap: widget.goalMap,
                                rootGoalId: subGoal.id,
                                onSelected: widget.onSelected,
                                selectedGoals: widget.selectedGoals,
                                expandedGoals: widget.expandedGoals,
                                onExpanded: widget.onExpanded,
                                depthLimit: widget.depthLimit == null
                                    ? null
                                    : widget.depthLimit! - 1,
                              )
                            : null,
                      AddSubgoalItemWidget(parentId: rootGoal.id),
                    ].where((element) => element != null).toList().cast())
              ])
            : Container()
      ],
    );
  }
}
